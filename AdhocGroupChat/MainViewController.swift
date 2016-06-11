/*
File: MainViewController.swift
Abstract:
This is the main view controller of the application.  It manages a iOS Messages like table view.  There are buttons for browsing for nearby peers and showing the a utility page. The table view data source is an array of Transcript objects which are created when sending or receving data (or image resources) via the MultipeerConnectivity data APIs.

Version: 1.0

Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
Inc. ("Apple") in consideration of your agreement to the following
terms, and your use, installation, modification or redistribution of
this Apple software constitutes acceptance of these terms.  If you do
not agree with these terms, please do not use, install, modify or
redistribute this Apple software.

In consideration of your agreement to abide by the following terms, and
subject to these terms, Apple grants you a personal, non-exclusive
license, under Apple's copyrights in this original Apple software (the
"Apple Software"), to use, reproduce, modify and redistribute the Apple
Software, with or without modifications, in source and/or binary forms;
provided that if you redistribute the Apple Software in its entirety and
without modifications, you must retain this notice and the following
text and disclaimers in all such redistributions of the Apple Software.
Neither the name, trademarks, service marks or logos of Apple Inc. may
be used to endorse or promote products derived from the Apple Software
without specific prior written permission from Apple.  Except as
expressly stated in this notice, no other rights or licenses, express or
implied, are granted by Apple herein, including but not limited to any
patent rights that may be infringed by your derivative works or by other
works in which the Apple Software may be incorporated.

The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.

IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
POSSIBILITY OF SUCH DAMAGE.

Copyright (C) 2013 Apple Inc. All Rights Reserved.

*/

import UIKit
import MultipeerConnectivity

class MainViewController: UITableViewController, MCBrowserViewControllerDelegate, SettingsViewControllerDelegate, UITextFieldDelegate, SessionContainerDelegate, UIActionSheetDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    // Constants for save/restore NSUserDefaults for the user entered display name and service type.
    let kNSDefaultDisplayName = "displayNameKey"
    let kNSDefaultServiceType = "serviceTypeKey"
    
    // Display name for local MCPeerID
    var displayName: String?
    // Service type for discovery
    var serviceType: String?
    // MC Session for managing peer state and send/receive data between peers
    var sessionContainer: SessionContainer!
    // TableView Data source for managing sent/received messages
    var transcripts: [Transcript]!
    // Map of resource names to transcripts array index
    var imageNameIndex: [String: Int]!
    // Text field used for typing text messages to send to peers
    @IBOutlet var messageComposeTextField: UITextField!
    // Button for executing the message send.
    @IBOutlet var sendMessageButton: UIBarButtonItem!
    
    // MARK: - Override super class methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Init transcripts array to use as table view data source
        transcripts = []
        imageNameIndex = [:]
        
        // Get the display name and service type from the previous session (if any)
        let defaults = NSUserDefaults.standardUserDefaults()
        displayName = defaults.stringForKey(kNSDefaultDisplayName)
        serviceType = defaults.stringForKey(kNSDefaultServiceType)
        
        if displayName != nil && serviceType != nil {
            // Show the service type (room name) as a title
            navigationItem.title = serviceType
            
            // create the session
            createSession()
        } else {
            performSegueWithIdentifier("Room Create", sender: self)
        }
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        // Listen for will show/hide notifications
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "keyboardWillShow:", name: UIKeyboardWillShowNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "keyboardWillHide:", name: UIKeyboardWillHideNotification, object: nil)
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        // Stop listening for keyboard notifications
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "Room Create" {
            
            // Prepare the settings view where the user inputs the 'serviceType' and local peer 'displayName'
            let navController = segue.destinationViewController as! UINavigationController
            let viewController = navController.topViewController as! SettingsViewController
            viewController.delegate = self
            // Pass the existing properties (if any) so the user can edit them.
            viewController.displayName = displayName
            viewController.serviceType = serviceType
        }
    }
    
    // MARK: - SettingsViewControllerDelegate methods
    
    // Delegate method implementation handling return from the "Create Chat Room" pages
    func controller(controller: SettingsViewController!, didCreateChatRoomWithDisplayName displayName: String!, serviceType: String!) {
        // Dismiss the modal view controller
        dismissViewControllerAnimated(true, completion: nil)
        
        // Cache these for MC session creation and changing later via the "info" button
        self.displayName = displayName
        self.serviceType = serviceType
        
        // Save these for subsequent app launches
        let defaults = NSUserDefaults.standardUserDefaults()
        defaults.setObject(displayName, forKey:kNSDefaultDisplayName)
        defaults.setObject(serviceType, forKey:kNSDefaultServiceType)
        defaults.synchronize()
        
        // Set the service type (aka Room Name) as the view controller title
        navigationItem.title = serviceType
        
        // Create the session
        createSession()
    }
    // MARK: - MCBrowserViewControllerDelegate methods
    
    // Override this method to filter out peers based on application specific needs
    func browserViewController(browserViewController: MCBrowserViewController, shouldPresentNearbyPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) -> Bool {
        return true
    }
    
    // Override this to know when the user has pressed the "done" button in the MCBrowserViewController
    func browserViewControllerDidFinish(browserViewController: MCBrowserViewController) {
        browserViewController.dismissViewControllerAnimated(true, completion: nil)
    }
    
    // Override this to know when the user has pressed the "cancel" button in the MCBrowserViewController
    func browserViewControllerWasCancelled(browserViewController: MCBrowserViewController) {
        browserViewController.dismissViewControllerAnimated(true, completion: nil)
    }
    
    // MARK: - SessionContainerDelegate
    func receivedTranscript(transcript: Transcript!) {
        // Add to table view data source and update on main thread
        dispatch_async(dispatch_get_main_queue(), {
            self.insertTranscript(transcript)
        })
    }
    
    func updateTranscript(transcript: Transcript!) {
        // Find the data source index of the progress transcript
        let index = imageNameIndex[transcript.imageName]!
        // Replace the progress transcript with the image transcript
        transcripts[index] = transcript
        
        // Reload this particular table view row on the main thread
        dispatch_async(dispatch_get_main_queue(), {
            let newIndexPath = NSIndexPath(forRow: index, inSection: 0)
            self.tableView.reloadRowsAtIndexPaths([newIndexPath], withRowAnimation: .Automatic)
        });
    }
    
    // MARK: - private methods
    
    // Private helper method for the Multipeer Connectivity local peerID, session, and advertiser.  This makes the application discoverable and ready to accept invitations
    func createSession() {
        // Create the SessionContainer for managing session related functionality.
        sessionContainer = SessionContainer(displayName: displayName, serviceType: serviceType)
        // Set this view controller as the SessionContainer delegate so we can display incoming Transcripts and session state changes in our table view.
        sessionContainer.delegate = self
    }
    
    // Helper method for inserting a sent/received message into the data source and reload the view.
    // Make sure you call this on the main thread
    func insertTranscript(transcript: Transcript) {
        // Add to the data source
        transcripts.append(transcript)
        
        // If this is a progress transcript add it's index to the map with image name as the key
        if transcript.progress != nil {
            let transcriptIndex = transcripts.count - 1
            imageNameIndex[transcript.imageName] = transcriptIndex
        }
        
        // Update the table view
        let newIndexPath = NSIndexPath(forRow: transcripts.count - 1, inSection: 0)
        tableView.insertRowsAtIndexPaths([newIndexPath], withRowAnimation:.Fade)
        
        // Scroll to the bottom so we focus on the latest message
        let numberOfRows = tableView.numberOfRowsInSection(0)
        if numberOfRows != 0 {
            tableView.scrollToRowAtIndexPath(NSIndexPath(forRow: (numberOfRows - 1), inSection: 0), atScrollPosition: .Bottom, animated: true)
        }
    }
    
    // MARK: - Table view data source
    
    // Only one section in this example
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    // The numer of rows is based on the count in the transcripts arrays
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return transcripts.count
    }
    
    // The individual cells depend on the type of Transcript at a given row.  We have 3 row types (i.e. 3 custom cells) for text string messages, resource transfer progress, and completed image resources
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        // Get the transcript for this row
        let transcript = transcripts[indexPath.row]
        
        // Check if it's an image progress, completed image, or text message
        let cell: UITableViewCell
        if transcript.imageUrl != nil {
            // It's a completed image
            cell = tableView.dequeueReusableCellWithIdentifier("Image Cell", forIndexPath:indexPath) 
            // Get the image view
            let imageView = cell.viewWithTag(Int(IMAGE_VIEW_TAG)) as! ImageView
            // Set up the image view for this transcript
            imageView.transcript = transcript
        }
        else if transcript.progress != nil {
            // It's a resource transfer in progress
            cell = tableView.dequeueReusableCellWithIdentifier("Progress Cell", forIndexPath:indexPath) 
            let progressView = cell.viewWithTag(Int(PROGRESS_VIEW_TAG)) as! ProgressView
            // Set up the progress view for this transcript
            progressView.transcript = transcript
        }
        else {
            // Get the associated cell type for messages
            cell = tableView.dequeueReusableCellWithIdentifier("Message Cell", forIndexPath:indexPath) 
            // Get the message view
            let messageView = cell.viewWithTag(Int(MESSAGE_VIEW_TAG)) as! MessageView
            // Set up the message view for this transcript
            messageView.transcript = transcript
        }
        return cell
    }
    
    // Return the height of the row based on the type of transfer and custom view it contains
    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        // Dynamically compute the label size based on cell type (image, image progress, or text message)
        let transcript = transcripts[indexPath.row]
        if transcript.imageUrl != nil {
            return ImageView.viewHeightForTranscript(transcript)
        }
        else if transcript.progress != nil {
            return ProgressView.viewHeightForTranscript(transcript)
        }
        else {
            return MessageView.viewHeightForTranscript(transcript)
        }
    }
    
    // MARK: - IBAction methods
    
    // Action method when pressing the "browse" (search icon).  It presents the MCBrowserViewController: a framework UI which enables users to invite and connect to other peers with the same room name (aka service type).
    @IBAction func browseForPeers(sender: AnyObject?) {
        // Instantiate and present the MCBrowserViewController
        let browserViewController = MCBrowserViewController(serviceType: serviceType!, session: sessionContainer.session)
        
        browserViewController.delegate = self
        browserViewController.minimumNumberOfPeers = kMCSessionMinimumNumberOfPeers
        browserViewController.maximumNumberOfPeers = kMCSessionMaximumNumberOfPeers
        
        presentViewController(browserViewController, animated:true, completion:nil)
    }
    
    // Action method when user presses "send"
    @IBAction func sendMessageTapped(sender: AnyObject?) {
        // Dismiss the keyboard.  Message will be actually sent when the keyboard resigns.
        messageComposeTextField.resignFirstResponder()
    }
    
    // Action method when user presses the "camera" photo icon.
    @IBAction func photoButtonTapped(sender: AnyObject?) {
        // Preset an action sheet which enables the user to take a new picture or select and existing one.
        let sheet = UIActionSheet(title: nil, delegate: self, cancelButtonTitle: "Cancel", destructiveButtonTitle: nil, otherButtonTitles: "Take Photo", "Choose Existing")
        
        // Show the action sheet
        sheet.showFromToolbar(navigationController!.toolbar)
    }
    
    // MARK: - UIImagePickerViewControllerDelegate
    
    // For responding to the user tapping Cancel.
    func imagePickerControllerDidCancel(picker: UIImagePickerController) {
        picker.dismissViewControllerAnimated(true, completion: nil)
    }
    
    // Override this delegate method to get the image that the user has selected and send it view Multipeer Connectivity to the connected peers.
    func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : AnyObject]) {
        picker.dismissViewControllerAnimated(true, completion: nil)
        // Don't block the UI when writing the image to documents
        dispatch_async(dispatch_get_global_queue(0, 0), {
            // We only handle a still image
            let imageToSave = info[UIImagePickerControllerOriginalImage] as! UIImage
            
            // Save the new image to the documents directory
            let pngData = UIImageJPEGRepresentation(imageToSave, 1.0)
            
            // Create a unique file name
            let inFormat = NSDateFormatter()
            inFormat.dateFormat = "yyMMdd-HHmmss"
            let imageName = String(format: "image-%@.JPG", inFormat.stringFromDate(NSDate()))
            // Create a file path to our documents directory
            let paths = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)
            let filePath = NSURL(fileURLWithPath: paths[0]).URLByAppendingPathComponent(imageName)
            let writePath = NSURL(fileURLWithPath: NSTemporaryDirectory()).URLByAppendingPathComponent("instagram.igo")
            pngData!.writeToFile(filePath.path!, atomically: true) // Write the file
          
            // Get a URL for this file resource
            let imageUrl = NSURL.fileURLWithPath(filePath.path!)
            
            // Send the resource to the remote peers and get the resulting progress transcript
            let transcript = self.sessionContainer.sendImage(imageUrl)
            
            // Add the transcript to the data source and reload
            dispatch_async(dispatch_get_main_queue(), {
                self.insertTranscript(transcript)
            });
        });
    }
    
    // MARK: - UITextFieldDelegate methods
    
    // Override to dynamically enable/disable the send button based on user typing
    func textField(textField: UITextField, shouldChangeCharactersInRange range: NSRange, replacementString string: String) -> Bool {
        let length = messageComposeTextField.text!.characters.count - range.length + string.characters.count
        if length > 0 {
            self.sendMessageButton.enabled = true;
        }
        else {
            self.sendMessageButton.enabled = false;
        }
        return true;
    }
    
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        textField.endEditing(true)
        return true
    }
    
    // Delegate method called when the message text field is resigned.
    func textFieldDidEndEditing(textField: UITextField) {
        // Check if there is any message to send
        if (messageComposeTextField.text!.characters.count > 0) {
            // Resign the keyboard
            textField.resignFirstResponder()
            
            // Send the message
            let transcript = sessionContainer.sendMessage(messageComposeTextField.text)
            
            if transcript != nil {
                // Add the transcript to the table view data source and reload
                insertTranscript(transcript)
            }
            
            // Clear the textField and disable the send button
            messageComposeTextField.text = ""
            sendMessageButton.enabled = false
        }
    }
    
    // MARK: - Toolbar animation helpers
    
    // Helper method for moving the toolbar frame based on user action
    func moveToolBarUp(up: Bool, forKeyboardNotification notification: NSNotification) {
        let userInfo = notification.userInfo!
        
        // Get animation info from userInfo
        let animationDuration = userInfo[UIKeyboardAnimationDurationUserInfoKey] as! NSTimeInterval
        let animationCurve = UIViewAnimationCurve(rawValue: userInfo[UIKeyboardAnimationCurveUserInfoKey] as! Int)!
        let keyboardFrame = (userInfo[UIKeyboardFrameEndUserInfoKey] as! NSValue).CGRectValue()
        
        // Animate up or down
        UIView.beginAnimations(nil, context: nil)
        UIView.setAnimationDuration(animationDuration)
        UIView.setAnimationCurve(animationCurve)
        
        navigationController!.toolbar.frame = CGRectMake(navigationController!.toolbar.frame.origin.x, navigationController!.toolbar.frame.origin.y + (keyboardFrame.size.height * (up ? -1 : 1)), navigationController!.toolbar.frame.size.width, navigationController!.toolbar.frame.size.height)
        UIView.commitAnimations()
    }
    
    func keyboardWillShow(notification: NSNotification) {
        // move the toolbar frame up as keyboard animates into view
        moveToolBarUp(true, forKeyboardNotification:notification)
    }
    
    func keyboardWillHide(notification: NSNotification) {
        // move the toolbar frame down as keyboard animates into view
        moveToolBarUp(false, forKeyboardNotification:notification)
    }
}
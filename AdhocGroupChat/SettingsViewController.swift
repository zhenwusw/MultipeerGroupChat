/*
File: SettingsViewController.swift
Abstract:
This view controller is used to manage a modal view that enables users to set a chat room name (aka Multipeer Connectivity 'serviceType' and a display name.  It also shows users how to use exception handling to detect invalid arguments passed to the framework API

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

class SettingsViewController: UIViewController, UITextFieldDelegate {
    
    var delegate: SettingsViewControllerDelegate?
    var displayName: String!
    var serviceType: String!
    
    let MCNearbyServiceMaxServiceTypeLength = 15
    
    @IBOutlet var displayNameTextField: UITextField!
    @IBOutlet var serviceTypeTextField: UITextField!
    
    override func viewDidLoad() {
        displayNameTextField.text = displayName;
        serviceTypeTextField.text = serviceType;
    }
    // MARK: - private
    
    // RFC 6335 text:
    //   5.1. Service Name Syntax
    //
    //     Valid service names are hereby normatively defined as follows:
    //
    //     o  MUST be at least 1 character and no more than 15 characters long
    //     o  MUST contain only US-ASCII [ANSI.X3.4-1986] letters 'A' - 'Z' and
    //        'a' - 'z', digits '0' - '9', and hyphens ('-', ASCII 0x2D or
    //        decimal 45)
    //     o  MUST contain at least one letter ('A' - 'Z' or 'a' - 'z')
    //     o  MUST NOT begin or end with a hyphen
    //     o  hyphens MUST NOT be adjacent to other hyphens
    //
    func isDisplayNameAndServiceTypeValid() -> Bool {
        if displayNameTextField.text == nil ||
            serviceTypeTextField.text == nil || // TODO: check for UTF-8
            (displayNameTextField.text!).characters.count > 63 ||
            displayNameTextField.text!.isEmpty ||
            (serviceTypeTextField.text!).characters.count > 15 ||
            serviceTypeTextField.text!.isEmpty { // TODO: check for ASCII
            return false
        }
        
        let peerID = MCPeerID(displayName: (displayNameTextField.text!))
        
        // Check if using this service type string causes a framework exception
        let advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: serviceTypeTextField.text!)
        
        print("Room Name [\(advertiser.serviceType)] (aka service type) and display name [\(peerID.displayName)] are valid")
        // all exception checks passed
        return true;
    }
    
    // MARK: - IBAction methods
    
    @IBAction func doneTapped(sender: AnyObject?) {
        if isDisplayNameAndServiceTypeValid() {
            // Fields are set.  send the values back to the delegate
            delegate?.controller(self, didCreateChatRoomWithDisplayName: displayNameTextField.text, serviceType: serviceTypeTextField.text)
        } else {
            // These are mandatory fields.  Alert the user
            let alert = UIAlertView(title: "Error", message: "You must set a valid room name and your display name", delegate: nil, cancelButtonTitle: "OK")
            alert.show()
        }
    }
    
    // MARK: - UITextFieldDelegate methods
    
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        view.endEditing(true)
        return true
    }
    
    func textFieldDidEndEditing(textField: UITextField) {
        view.endEditing(true)
    }
}

protocol SettingsViewControllerDelegate {
    func controller(controller: SettingsViewController!, didCreateChatRoomWithDisplayName displayName: String!, serviceType: String!)
}
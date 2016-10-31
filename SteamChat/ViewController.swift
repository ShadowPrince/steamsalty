//
//  ViewController.swift
//  SteamChat
//
//  Created by shdwprince on 10/17/16.
//  Copyright © 2016 shdwprince. All rights reserved.
//

import UIKit
import Alamofire

class WebAuthenticationViewController: UIViewController, UISplitViewControllerDelegate {
    @IBOutlet weak var webView: UIWebView!

    override func viewDidLoad() {
        super.viewDidLoad()

        self.webView.loadRequest(URLRequest(url: URL(string: "http://steamcommunity.com/chat")!))
    }
}

class SplitViewController: UISplitViewController, UISplitViewControllerDelegate {
    override func viewDidLoad() {
        super.viewDidLoad()

        self.delegate = self

        SteamApi.sharedInit()
        //SteamPollManager.shared.start()

        let navigationController = self.viewControllers.first as! UINavigationController
        navigationController.isNavigationBarHidden = true
        navigationController.interactivePopGestureRecognizer?.delegate = nil
    }

    func splitViewController(_ splitViewController: UISplitViewController, collapseSecondary secondaryViewController: UIViewController, onto primaryViewController: UIViewController) -> Bool {
        return true
    }
}


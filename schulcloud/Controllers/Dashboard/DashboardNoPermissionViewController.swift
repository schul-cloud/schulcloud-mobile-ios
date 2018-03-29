//
//  DashboardNoPermissionViewController.swift
//  schulcloud
//
//  Created by Florian Morel on 14.03.18.
//  Copyright © 2018 Hasso-Plattner-Institut. All rights reserved.
//

import UIKit

final class DashboardNoPermissionViewController : UIViewController, ViewControllerHeightDataSource {

    @IBOutlet var label : UILabel!

    var missingPermission : UserPermissions = UserPermissions.none {
        didSet {
            self.label?.text?.append("\n(\(missingPermission.description))")
        }
    }

    var height: CGFloat {
        return 200.0
    }

}
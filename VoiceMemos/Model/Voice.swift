//
//  Voice.swift
//  VoiceMemos
//
//  Created by Zhouqi Mo on 2/20/15.
//  Copyright (c) 2015 Zhouqi Mo. All rights reserved.
//

import Foundation
import CoreData

class Voice: NSManagedObject {

    @NSManaged var date: NSDate
    @NSManaged var filename: String?
    @NSManaged var subject: String
    @NSManaged var duration: NSNumber

}

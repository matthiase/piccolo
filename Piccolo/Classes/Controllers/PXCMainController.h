//
//  PXCViewController.h
//  Piccolo
//
//  Created by Matthias Eder on 4/22/13.
//  Copyright (c) 2013 Matthias Eder. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PXCDataStore.h"

@interface PXCMainController : UIViewController<UINavigationControllerDelegate, UIImagePickerControllerDelegate>
{
    
}

@property (nonatomic, strong) PXCDataStore *datastore;

-(IBAction)uploadImage:(id)sender;

@end

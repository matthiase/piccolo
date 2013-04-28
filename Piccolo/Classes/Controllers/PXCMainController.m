//
//  PXCViewController.m
//  Piccolo
//
//  Created by Matthias Eder on 4/22/13.
//  Copyright (c) 2013 Matthias Eder. All rights reserved.
//

#import <MobileCoreServices/UTCoreTypes.h>
#import "PXCMainController.h"
#import "PXCDataStore.h"

@interface PXCMainController ()

@end

@implementation PXCMainController


#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    [[PXCDataStore sharedClient] createBucket:^(NSError *error) {
        if (!error) {
            [self listObjects];
        }
        else {
            if ([error code] == 403) { 
                // Invalid credentials - show the settings
                NSString *message = @"Invalid Amazon credentials. Please enter a valid "
                                     "access key and secret in Settings > Piccolo.";
                [self showAlertMessage:message withTitle:@"Error"];
            }
            else {
                [self showAlertMessage:[error localizedDescription] withTitle:@"Error"];
            }
        }
    }];
}
     
#pragma mark - Action handlers

-(IBAction)uploadImage:(id)sender
{
    [self showImagePicker];
}


#pragma mark - UIImagePickerControllerDelegate methods

-(void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    // Detect the selected file's media type.
    NSString *mediaType = [info objectForKey: UIImagePickerControllerMediaType];
    
    // Examine the reference url of the chosen image and extract the "id" and "ext" parameters.
    NSURL *fileUrl = [info objectForKey:UIImagePickerControllerReferenceURL];
    NSMutableDictionary *fileAttributes = [[NSMutableDictionary alloc] init];
    
    NSArray *keyValuePairs = nil;
    for (NSString *param in [fileUrl.query componentsSeparatedByString:@"&"]) {
        keyValuePairs = [param componentsSeparatedByString:@"="];
        [fileAttributes setValue:keyValuePairs[1] forKey:keyValuePairs[0]];
    }

    NSString *mediaExt = [fileAttributes objectForKey:@"ext"];
    NSString *mediaKey = [[fileAttributes objectForKey:@"id"] stringByAppendingPathExtension:mediaExt];
    NSData *content;
    NSString *contentType;
        
    // Get the data of the chosen file and convert it to the correct format (if necessary).  The
    // processing instructions vary by media type.
    if (CFStringCompare ((__bridge CFStringRef) mediaType, kUTTypeImage, 0) == kCFCompareEqualTo) {
        UIImage *image = [info objectForKey:UIImagePickerControllerOriginalImage];
        content = UIImageJPEGRepresentation(image, 1.0);
        contentType = @"image/jpeg";
    }
    else if (CFStringCompare ((__bridge CFStringRef) mediaType, kUTTypeMovie, 0) == kCFCompareEqualTo) {
        NSString *movieUrl = [[info objectForKey:UIImagePickerControllerMediaURL] path];
        content = [NSData dataWithContentsOfURL:[NSURL fileURLWithPath:movieUrl]];
        contentType = @"video/quicktime";
    }
    else {
        [self showAlertMessage:[NSString stringWithFormat:@"Files of type \"%@\" are currently not supported.", mediaExt]
                     withTitle:@"Sorry"];
    }
    
    // If content is available (i.e.) the media type is supported, upload the file.
    if (content) {
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
        [self uploadObject:content ofType:contentType withKey:mediaKey];
    }
        
    [picker dismissViewControllerAnimated:YES completion:nil];
}


-(void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [picker dismissViewControllerAnimated:YES completion:nil];
}


#pragma mark - Helper Methods

-(void)listObjects
{
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    [[PXCDataStore sharedClient] listObjects:^(NSArray *results, NSError *error) {
        if (error) {
            [self showAlertMessage:[NSString stringWithFormat:@"%@", error] withTitle:@"Error"];
        }
        else {
            for (int i = 0; i < [results count]; i++) {
                NSLog(@"Object: %@", [results objectAtIndex:i]);
                //[self getObject:[results objectAtIndex:i]];
            }
        }
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    }];
}


-(void)getObjectMetadata
{
    
}


-(void)getObject:(NSString *) key
{
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    [[PXCDataStore sharedClient] getObject:key withBlock:^(NSData *data, NSError *error) {
        if (error) {
            [self showAlertMessage:[NSString stringWithFormat:@"%@", error] withTitle:@"Error"];
        }
        else {
            //UIImage *image = [[UIImage alloc] initWithData:data];
            NSLog(@"Got image data for %@", key);
        }
    }];
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
}


-(void)uploadObject:(NSData *) data ofType:type withKey:key
{
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    [[PXCDataStore sharedClient] writeObject:data ofType:type WithKey:key andBlock:^(NSError *error) {
        NSString *title = @"Success";
        NSString *message = @"Upload complete.";
        if (error) {
            title = @"Error";
            message = [NSString stringWithFormat:@"%@", error];
        }
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
        [self showAlertMessage:message withTitle:title];
    }];
}


-(void)showImagePicker
{
    UIImagePickerController *imagePicker = [[UIImagePickerController alloc] init];
    imagePicker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    imagePicker.mediaTypes = [[NSArray alloc] initWithObjects:(NSString *)kUTTypeImage, (NSString *)kUTTypeMovie, nil];
    imagePicker.delegate = self;
    [self presentViewController:imagePicker animated:YES completion:nil];
}


- (void)showAlertMessage:(NSString *)message withTitle:(NSString *)title
{
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:title
                                                         message:message
                                                        delegate:nil
                                               cancelButtonTitle:@"OK"
                                               otherButtonTitles:nil];
    [alertView show];
}

@end

//
// PXCDataStore.h
//
// Copyright (c) 2013 Matthias Eder
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import <AWSRuntime/AWSRuntime.h>

/**
 `PXCDataStore` is a convenience wrapper around a subset of the Amazon S3 client
 library, providing a simple API for asynchronously creating buckets, as well as
 storing, retrieving and listing objects stored in a bucket.
 
 The current implementation could be vastly improved by supporing pagination when
 listing objects in a S3 bucket.  Implementing the AmazonServiceRequestDelegate
 would also be nice because it would enable class to support some more advanced
 features like a progress meter.
 */

@interface PXCDataStore : NSObject

/**
 Creates and returns a `PXCDataStore` object.
 */
+(instancetype)sharedClient;

/**
 Reinitializes the current `PXCDataStore` object with the stored user preferences.
 Calling this method is only necessary if the user updates his/her settings.
 */
+(void)reconnect;

/**
 Creates the default S3 bucket using the name derived from the channel name and AWS
 access key.
 
 @param block A block object to be executed when the task finishes. The block has no
    return value and takes one argument: a NSError object describing any error that
    may have occurred.
 */
-(void)createBucket:(void(^)(NSError *error))block;

/**
 Lists the objects currently stored in the default bucket. This method is currently
 just a proof of concept and does not yet support pagination.
 
 @param block A block object to be executed when the task finishes. The block has no
    return value and takes two arguments: a NSArray containing the keys of first 20
    objects found in the bucket and a NSError object describing any error that may
    have occurred.
 */
-(void)listObjects:(void (^)(NSArray *results, NSError *error))block;

/**
 Fetches an object matching the specified key from the default Amazon S3 bucket.
 
 @param NSString key The key of the object to fetch
 @param block A block object to be executed when the task finishes. The block has no
 return value and takes two arguments: a NSData object containing the response data
 and a NSError object describing any error that may have occurred.
 */
-(void)getObject:(NSString *)key
       withBlock:(void (^)(NSData *data, NSError *error))block;

/**
 Stores an object to the defauls Amazon S3 bucket and associates it with the provided
 key and MIME type.
 
 @param NSData data The data to be written to the bucket.
 @param NSString objectType The MIME type of object (e.g. "image/jpeg)".
 @param block A block object to be executed when the task finishes. The block has no
 return value and takes one argument: a NSError object describing any error that
 may have occurred.
 */
-(void)writeObject:(NSData *)data
            ofType:(NSString*)objectType
           WithKey:(NSString *)key
          andBlock:(void (^)(NSError *error))block;

@end

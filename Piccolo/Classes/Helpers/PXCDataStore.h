//
//  PXCDataStore.h
//  Piccolo
//
//  Created by Matthias Eder on 4/22/13.
//  Copyright (c) 2013 Matthias Eder. All rights reserved.
//

#import <AWSRuntime/AWSRuntime.h>

@interface PXCDataStore : NSObject<AmazonServiceRequestDelegate>

+(PXCDataStore *)sharedClient;
+(void)reconnect;
-(void)createBucket:(void(^)(NSError *error))block;
-(void)listObjects:(void (^)(NSArray *results, NSError *error))block;
-(void)getObject:(NSString *)key withBlock:(void (^)(NSData *data, NSError *error))block;
-(void)writeObject:(NSData *)data ofType:(NSString*)objectType WithKey:(NSString *)key andBlock:(void (^)(NSError *error))block;

@end

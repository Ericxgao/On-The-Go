//
//  OTGNetworkRequest.h
//  On The Go
//
//  Created by Eric Gao on 7/3/14.
//  Copyright (c) 2014 Eric Gao. All rights reserved.
//

#import "AFHTTPRequestOperation.h"
#import <CoreLocation/CoreLocation.h>

@interface OTGNetworkRequest : NSObject

+ (void)fetchPotentialPlacesWithString:(NSString *) searchString withLocation:(CLLocation *)currentLocation success:(void (^)(AFHTTPRequestOperation *operation, id responseObject))success;

+ (void)fetchPlaceDetailsWithReference:(NSString *) reference success:(void (^)(AFHTTPRequestOperation *operation, id responseObject))success;

+ (void)fetchPlaceDetailsWithDescription:(NSString *) description withLocation:(CLLocation *)currentLocation success:(void (^)(AFHTTPRequestOperation *operation, id responseObject))success;

+ (void)fetchRouteWithStart:(CLLocation *)startLocation withEnd:(CLLocation *)endLocation success:(void (^)(AFHTTPRequestOperation *operation, id responseObject))success;
@end

//
//  OTGMapViewViewController.m
//  On The Go
//
//  Created by Eric Gao on 7/1/14.
//  Copyright (c) 2014 Eric Gao. All rights reserved.
//

#import "OTGMapViewViewController.h"
#import "OTGNetworkRequest.h"
#import "OTGSearchBarCell.h"
#import <GoogleMaps/GoogleMaps.h>
#import <CoreLocation/CoreLocation.h>

@interface OTGMapViewViewController () <UISearchBarDelegate, UISearchDisplayDelegate, UITableViewDataSource, UITableViewDelegate, GMSMapViewDelegate, UITextFieldDelegate>

@property (nonatomic, strong) IBOutlet GMSMapView *mapView;
@property (nonatomic, strong) IBOutlet UISearchBar *startSearchBar;
@property (nonatomic, strong) IBOutlet UISearchBar *endSearchBar;
@property (nonatomic, strong) IBOutlet UIView *detailView;
@property (nonatomic, strong) IBOutlet UIView *yelpSearchView;
@property (nonatomic, strong) IBOutlet UILabel *mainAddress;
@property (nonatomic, strong) IBOutlet UILabel *subAddress;
@property (nonatomic, strong) IBOutlet UILabel *estimatedDistanceAndTimeLabel;
@property (nonatomic, strong) IBOutlet UIButton *showRouteButton;
@property (nonatomic, strong) IBOutlet UIButton *showYelpSearchViewButton;
@property (nonatomic, strong) IBOutlet UIButton *hideYelpSearchViewButton;
@property (nonatomic, strong) IBOutlet UIButton *yelpSearchButton;
@property (nonatomic, strong) IBOutlet UITextField *yelpSearchTextField;
@property (nonatomic, strong) IBOutlet UITextField *timeTextField;
@property (nonatomic, strong) IBOutlet UITextField *radiusTextField;
@property (nonatomic, strong) IBOutlet NSLayoutConstraint *keyboardBottomConstraint;
@property (nonatomic, strong) IBOutlet NSLayoutConstraint *keyboardTopConstraint;
@property (nonatomic, strong) IBOutlet NSLayoutConstraint *detailViewBottomConstraint;
@property (nonatomic, strong) IBOutlet NSLayoutConstraint *detailViewTopConstraint;
@property (nonatomic, strong) IBOutlet NSLayoutConstraint *timeLabelWidthConstraint;
@property (nonatomic, strong) IBOutlet NSLayoutConstraint *radiusLabelWidthConstraint;
@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic, strong) CLLocation *currentLocation;
@property (nonatomic, strong) UISearchDisplayController *startSearchController;
@property (nonatomic, strong) UISearchDisplayController *endSearchController;
@property (nonatomic, strong) NSMutableArray *places;
@property (nonatomic, strong) CLLocation *startLocation;
@property (nonatomic, strong) CLLocation *endLocation;
@property (nonatomic, strong) NSString *startAddress;
@property (nonatomic, strong) NSString *endAddress;
@property (nonatomic, strong) NSString *travelTime;
@property (nonatomic, strong) NSString *distance;
@property (nonatomic, strong) GMSMarker *startMarker;
@property (nonatomic, strong) GMSMarker *endMarker;
@property (nonatomic, strong) NSMutableArray *routes;
@property (nonatomic, strong) GMSPolyline *routeLine;

@end

@implementation OTGMapViewViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.view addSubview:self.yelpSearchView];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];

    // Remove the border from search bar
    [self.startSearchBar setBackgroundImage:[[UIImage alloc] init]];
    [self.endSearchBar setBackgroundImage:[[UIImage alloc] init]];
    
    // Set up detail/yelp search view frame and gradient
    CAGradientLayer *layer = [CAGradientLayer layer];
    layer.frame = self.detailView.bounds;
    layer.colors = [NSArray arrayWithObjects:(id)[UIColor whiteColor].CGColor, (id)[UIColor colorWithWhite:1 alpha:0].CGColor, nil];
    layer.startPoint = CGPointMake(1.0f, 1.0f);
    layer.endPoint = CGPointMake(1.0f, 0.0f);
    [self.detailView.layer insertSublayer:layer atIndex:0];
    
    layer.frame = self.yelpSearchView.bounds;
    [self.yelpSearchView.layer insertSublayer:layer atIndex:0];
    
    self.detailViewBottomConstraint.constant = -55;
    self.detailViewTopConstraint.constant = 568;
    
    self.keyboardBottomConstraint.constant = -65;
    self.keyboardTopConstraint.constant = 568;
    
    // Set up start search bar and search controller
    self.startSearchBar.delegate = self;
    self.startSearchController = [[UISearchDisplayController alloc] initWithSearchBar:self.startSearchBar contentsController:self];
    self.startSearchController.delegate = self;
    self.startSearchController.searchResultsDataSource = self;
    self.startSearchController.searchResultsDelegate = self;
    
    // Set up end search bar and search controller
    self.endSearchBar.delegate = self;
    self.endSearchController = [[UISearchDisplayController alloc] initWithSearchBar:self.endSearchBar contentsController:self];
    self.endSearchController.delegate = self;
    self.endSearchController.searchResultsDataSource = self;
    self.endSearchController.searchResultsDelegate = self;
    
    // Set up map view and center to user location
    self.mapView.delegate = self;
    
    self.locationManager = [[CLLocationManager alloc] init];
    self.locationManager.distanceFilter = kCLDistanceFilterNone;
    self.locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters;
    [self.locationManager startUpdatingLocation];
    
    self.currentLocation = self.locationManager.location;
    CLLocationDegrees latitude = self.currentLocation.coordinate.latitude;
    CLLocationDegrees longitude = self.currentLocation.coordinate.longitude;
    
    GMSCameraPosition *camera = [GMSCameraPosition cameraWithLatitude:latitude longitude:longitude zoom:12];

    self.mapView.camera = camera;
    
    // Set up search bar table views
    [self.startSearchController.searchResultsTableView setTableFooterView:[[UIView alloc] initWithFrame:CGRectZero]];
    [self.endSearchController.searchResultsTableView setTableFooterView:[[UIView alloc] initWithFrame:CGRectZero]];
    
    // Attach actions to buttons
    [self.yelpSearchButton addTarget:self action:@selector(yelpSearch) forControlEvents:UIControlEventTouchUpInside];
    [self.showRouteButton addTarget:self action:@selector(showRoute) forControlEvents:UIControlEventTouchUpInside];
    [self.showYelpSearchViewButton addTarget:self action:@selector(showYelpSearchView) forControlEvents:UIControlEventTouchUpInside];
    [self.hideYelpSearchViewButton addTarget:self action:@selector(hideYelpSearchView) forControlEvents:UIControlEventTouchUpInside];

    // Set up text field delegates
    self.yelpSearchTextField.delegate = self;
    self.timeTextField.delegate = self;
    self.radiusTextField.delegate = self;
}

// Searches for suggested places when user inputs an address
- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    [OTGNetworkRequest fetchPotentialPlacesWithString:searchText withLocation:self.currentLocation success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSDictionary *json = responseObject;
        
        NSArray *predictions = [json valueForKey:@"predictions"];
        self.places = [[NSMutableArray alloc] init];
        for (NSDictionary *place in predictions) {
            [self.places addObject:@{@"description":[place valueForKey:@"description"],
                                            @"reference":[place valueForKey:@"reference"]}];
        }
        if (searchBar == self.startSearchBar) {
            [self.startSearchController.searchResultsTableView reloadData];
        }
    }];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    // When a place is selected, zoom in to the point and drop a marker
    NSString *reference = self.places[indexPath.row][@"reference"];
    [OTGNetworkRequest fetchPlaceDetailsWithReference:reference success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSDictionary *json = responseObject;
        NSDictionary *result = [json valueForKey:@"result"];
        CLLocationDegrees latitude = [result[@"geometry"][@"location"][@"lat"] doubleValue];
        CLLocationDegrees longitude = [result[@"geometry"][@"location"][@"lng"] doubleValue];
        
        // Remove a path if one exists
        self.routeLine.map = nil;
        
        if (tableView == self.startSearchController.searchResultsTableView) {
            [self.startSearchController setActive:NO animated:YES];
            self.endSearchBar.hidden = NO;
            
            self.startAddress = result[@"formatted_address"];
            self.startLocation = [[CLLocation alloc] initWithLatitude:latitude longitude:longitude];
            
            self.startSearchBar.text = self.places[indexPath.row][@"description"];
            
            GMSCameraPosition *startPosition = [GMSCameraPosition cameraWithLatitude:self.startLocation.coordinate.latitude longitude:self.startLocation.coordinate.longitude zoom:15];
            [self.mapView setCamera:startPosition];
            
            CLLocationCoordinate2D position = CLLocationCoordinate2DMake(latitude, longitude);
            self.startMarker.map = nil;
            self.startMarker = [GMSMarker markerWithPosition:position];
            self.startMarker.title = @"Start Location";
            self.startMarker.map = self.mapView;
            [self showDetailViewForMarker:self.startMarker];
        
        } else if (tableView == self.endSearchController.searchResultsTableView) {
            [self.endSearchController setActive:NO animated:YES];
            
            self.endAddress = result[@"formatted_address"];
            self.endLocation = [[CLLocation alloc] initWithLatitude:latitude longitude:longitude];
            
            self.endSearchBar.text = self.places[indexPath.row][@"description"];
            
            GMSCameraPosition *endPosition = [GMSCameraPosition cameraWithLatitude:self.endLocation.coordinate.latitude longitude:self.endLocation.coordinate.longitude zoom:15];
            [self.mapView setCamera:endPosition];
            
            CLLocationCoordinate2D position = CLLocationCoordinate2DMake(latitude, longitude);
            self.endMarker.map = nil;
            self.endMarker = [GMSMarker markerWithPosition:position];
            self.endMarker.title = @"End Location";
            self.endMarker.map = self.mapView;
            [self showDetailViewForMarker:self.endMarker];
            
            self.showRouteButton.hidden = NO;
        }
    }];
}

#pragma Table View Delegate
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    OTGSearchBarCell *cell = [[OTGSearchBarCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"placeCell"];
    if ([self.places count]) {
        cell.textLabel.text = self.places[indexPath.row][@"description"];
        cell.reference = self.places[indexPath.row][@"reference"];
    }
    
    return cell;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.places count];
}

#pragma Map View Delegate
- (BOOL)mapView:(GMSMapView *)mapView didTapMarker:(GMSMarker *)marker {
    [self showDetailViewForMarker:marker];
    return YES;
}

- (void)mapView:(GMSMapView *)mapView didTapAtCoordinate:(CLLocationCoordinate2D)coordinate {
    // Hide the detail view
    [self hideDetailView];
    
    // Dismiss the keyboard
    [self.view endEditing:YES];
}

#pragma Text Field Delegate
- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    // Jump to the next field unless it is the last field, in which case submit
    if (textField == self.yelpSearchTextField) {
        [self.timeTextField becomeFirstResponder];
        return NO;
    }
    
    if (textField == self.timeTextField) {
        [self.radiusTextField becomeFirstResponder];
        return NO;
    }

    return YES;
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    NSString *currentInput = textField.text;
    NSString *fullInput = [NSString stringWithFormat:@"%@%@", currentInput, string];
    if (textField == self.timeTextField) {
        if ([string isEqualToString:@""]) {
            if (fullInput.length <= 1) {
                self.timeLabelWidthConstraint.constant = 44;
                return YES;
            }
            CGSize stringSize = [[fullInput substringToIndex:fullInput.length - 1] sizeWithAttributes:@{NSFontAttributeName: [UIFont systemFontOfSize:14]}];
            self.timeLabelWidthConstraint.constant = ceil(stringSize.width) + 4;
        } else {
            CGSize stringSize = [fullInput sizeWithAttributes:@{NSFontAttributeName: [UIFont systemFontOfSize:14]}];
            self.timeLabelWidthConstraint.constant = ceil(stringSize.width) + 4;
        }
    } else if (textField == self.radiusTextField) {
        if ([string isEqualToString:@""]) {
            if (fullInput.length <= 1) {
                self.radiusLabelWidthConstraint.constant = 44;
                return YES;
            }
            CGSize stringSize = [[fullInput substringToIndex:fullInput.length - 1] sizeWithAttributes:@{NSFontAttributeName: [UIFont systemFontOfSize:14]}];
            self.radiusLabelWidthConstraint.constant = ceil(stringSize.width) + 4;
        } else {
            CGSize stringSize = [fullInput sizeWithAttributes:@{NSFontAttributeName: [UIFont systemFontOfSize:14]}];
            self.radiusLabelWidthConstraint.constant = ceil(stringSize.width) + 4;
        }
    }
    
    
    return YES;
}

#pragma Private Methods
- (void)hideDetailView {
    [UIView animateWithDuration:0.2 animations:^{
        self.detailViewBottomConstraint.constant = -55;
        self.detailViewTopConstraint.constant = 568;
        [self.view layoutIfNeeded];
    }];
}

- (void)showDetailView {
    [UIView animateWithDuration:0.2 animations:^{
        self.detailViewTopConstraint.constant = 513;
        self.detailViewBottomConstraint.constant = 0;
        [self.view layoutIfNeeded];
    }];
}

- (void)hideYelpSearchView {
    [UIView animateWithDuration:0.2 animations:^{
        self.keyboardBottomConstraint.constant = -78;
        self.keyboardTopConstraint.constant = 568;
        [self.view layoutIfNeeded];
    }];
    
    [self showDetailView];
}

- (void)showYelpSearchView {
    [UIView animateWithDuration:0.2 animations:^{
        self.keyboardTopConstraint.constant = 490;
        self.keyboardBottomConstraint.constant = 0;
        [self.view layoutIfNeeded];
    }];
    
    [self hideDetailView];
}

// Convenience method to convert meters to miles, since the API returns distance in meters
- (NSString *)convertMetersToMiles:(NSInteger)meters {
    CGFloat miles = meters * 0.000621371;
    NSString *milesString = [NSString stringWithFormat:@"%.1f mi", miles];
    
    return milesString;
}

// Convenience method to convert seconds into minutes, since the API returns travel time in seconds
- (NSString *)convertSecondsToHoursMinutes:(NSInteger)seconds {
    NSInteger hours = floor(seconds / 3600);
    NSInteger remainingSeconds = seconds - (hours * 3600);
    NSInteger minutes = ceil(remainingSeconds / 60);
    NSString *hoursMinutesString = @"";
    if (hours > 0) {
        if (minutes > 0) {
            hoursMinutesString = [NSString stringWithFormat:@"%@ hrs, %@ min", @(hours), @(minutes)];
        } else {
            hoursMinutesString = [NSString stringWithFormat:@"%@ hrs", @(hours)];
        }
    } else {
        hoursMinutesString = [NSString stringWithFormat:@"%@ min", @(minutes)];
    }
    
    return hoursMinutesString;
}

- (void)showDetailViewForMarker:(GMSMarker *)marker {
    [self.view addSubview:self.detailView];
    if (marker == self.startMarker) {
        NSRange range = [self.startAddress rangeOfString:@","];
        if (range.location < self.startAddress.length) {
            NSString *mainAddress = [self.startAddress substringToIndex:range.location];
            NSString *subAddress = [self.startAddress substringFromIndex:range.location + 2];
            self.mainAddress.text = mainAddress;
            self.subAddress.text = subAddress;
        } else {
            self.mainAddress.text = self.startAddress;
        }
    } else if (marker == self.endMarker) {
        NSRange range = [self.endAddress rangeOfString:@","];
        if (range.location < self.endAddress.length) {
            NSString *mainAddress = [self.endAddress substringToIndex:range.location];
            NSString *subAddress = [self.endAddress substringFromIndex:range.location + 2];
            self.mainAddress.text = mainAddress;
            self.subAddress.text = subAddress;
        } else {
            self.mainAddress.text = self.endAddress;
        }
    }
    
    [self showDetailView];
    
    [self hideYelpSearchView];
}

- (IBAction)showRoute {
    [OTGNetworkRequest fetchRouteWithStart:self.startLocation withEnd:self.endLocation success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSDictionary *json = responseObject;
        NSArray *routes = json[@"routes"];
        GMSMutablePath *path = [[GMSMutablePath alloc] init];
        
        [self.routes removeAllObjects];
        self.routes = [[NSMutableArray alloc] init];
        
        // Lots of loops here, but there are rarely more than one route and never more than two legs
        
        for (int i = 0; i < routes.count; i++) {
            NSArray *legs = routes[i][@"legs"];
            NSMutableArray *steps = [[NSMutableArray alloc] init];
            NSInteger distance = 0;
            NSInteger travelTime = 0;
            
            for (int j = 0; j < legs.count; j++) {
                distance += [legs[j][@"distance"][@"value"] intValue];
                travelTime += [legs[j][@"duration"][@"value"] intValue];
                [steps addObjectsFromArray:legs[j][@"steps"]];
                
                for (int k = 0; k < steps.count; k++) {
                    NSString *encodedPolyline = steps[k][@"polyline"][@"points"];
                    GMSPath *decodedPath = [GMSPath pathFromEncodedPath:encodedPolyline];
                    
                    for (int l = 0; l < decodedPath.count; l++) {
                        // Here we add coordinates to a large, precise path from the paths of each step
                        // Overview polyline does not give us the necessary precision when zooming in on longer trips
                        [path addCoordinate:[decodedPath coordinateAtIndex:l]];
                    }
                }
            }
            
            NSDictionary *route = @{
                                    @"path" : path,
                                    @"distance" : [NSNumber numberWithInteger:distance],
                                    @"travelTime" : [NSNumber numberWithInteger:travelTime],
                                    @"steps" : steps};
            
            [self.routes addObject:route];
        }
            // For now, just take the first route in the list
            NSInteger routeIndex = 0;
            self.routeLine.map = nil;
            self.routeLine = [GMSPolyline polylineWithPath:self.routes[routeIndex][@"path"]];
            self.routeLine.strokeColor = [UIColor blueColor];
            self.routeLine.strokeWidth = 3;
            self.routeLine.map = self.mapView;
            
            // Converting distance and time to readable values
            NSInteger distance = [self.routes[routeIndex][@"distance"] intValue];
            NSInteger travelTime = [self.routes[routeIndex][@"travelTime"] intValue];
            
            self.distance = [self convertMetersToMiles:distance];
            self.travelTime = [self convertSecondsToHoursMinutes:travelTime];
        
            // Update yelp Search View with new distance and time
            self.estimatedDistanceAndTimeLabel.text = [NSString stringWithFormat:@"Distance: %@, Travel Time: %@", self.distance, self.travelTime];
            
            GMSCoordinateBounds *bounds = [[GMSCoordinateBounds alloc] initWithPath:self.routes[routeIndex][@"path"]];
            [self.mapView animateWithCameraUpdate:[GMSCameraUpdate fitBounds:bounds withPadding:50]];
        }];
    }

- (void)yelpSearch {
    [self yelpSearchWithSearchString:self.yelpSearchTextField.text atTime:[self.timeTextField.text intValue] withRadius:[self.radiusTextField.text intValue]];
}

- (void)yelpSearchWithSearchString:(NSString *)searchString atTime:(NSInteger)minutes withRadius:(NSInteger)radius {
    NSDictionary *stepDictionary = [self getStepAtTime:minutes];
    NSDictionary *step = stepDictionary[@"step"];
    
    NSString *encodedPolyline = step[@"polyline"][@"points"];
    
    GMSPath *decodedPath = [GMSPath pathFromEncodedPath:encodedPolyline];
    NSMutableArray *pathPoints = [[NSMutableArray alloc] init];
    
    for (int i = 0; i < decodedPath.count; i++) {
        CLLocationCoordinate2D pathPoint = [decodedPath coordinateAtIndex:i];
        CLLocation *pathLocation = [[CLLocation alloc] initWithLatitude:pathPoint.latitude longitude:pathPoint.longitude];
        [pathPoints addObject:pathLocation];
    }
    
    [self getPointAtTime:minutes withPoints:pathPoints withMin:0 withMax:pathPoints.count];
}

// In order to calculate the position at a certain time, loop through all steps of the route and add up their durations until the time is equal to or greater than the specified time
- (NSDictionary *)getStepAtTime:(NSInteger)minutes {
    NSInteger seconds = minutes * 60;
    NSInteger totalTime = 0;
    NSMutableArray *steps = self.routes[0][@"steps"];
    for (int i = 0; i < steps.count; i++) {
        totalTime += [steps[i][@"duration"][@"value"] intValue];
        if (totalTime >= seconds) {
            NSNumber *timeAtStep = @(totalTime - [steps[i][@"duration"][@"value"] intValue]);
            return @{@"step" : steps[i], @"timeAtStep" : timeAtStep};
        }
    }
    
    // If totalTime does not exceed the predicted time, return the last step
    NSNumber *timeAtStep = @(totalTime - [steps[steps.count -1][@"duration"][@"value"] intValue]);
    return @{@"step" : steps[steps.count - 1], @"timeAtStep" : timeAtStep};
}

- (void)getPointAtTime:(NSInteger)minutes withPoints:(NSArray *)points withMin:(NSInteger)min withMax:(NSInteger)max {
    NSInteger mid;
    NSInteger seconds = minutes * 60;
    
    if (max < min) {
        CLLocation *location = (CLLocation *)points[min];
        CLLocationCoordinate2D position = CLLocationCoordinate2DMake(location.coordinate.latitude, location.coordinate.longitude);
        GMSMarker *marker = [GMSMarker markerWithPosition:position];
        marker.map = self.mapView;
        
        [OTGNetworkRequest fetchDistanceBetweenStart:self.startLocation andEnd:(CLLocation *)points[min] success:^(AFHTTPRequestOperation *operation, id responseObject) {
            NSDictionary *json = responseObject;
            NSDictionary *element = json[@"rows"][0][@"elements"][0];
            NSLog(@"%d", [element[@"duration"][@"value"] intValue]);
        }];
        return;
    }
    
    mid = (min + max) / 2;
    
    [OTGNetworkRequest fetchDistanceBetweenStart:self.startLocation andEnd:(CLLocation *)points[mid] success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSDictionary *json = responseObject;
        NSDictionary *element = json[@"rows"][0][@"elements"][0];
        NSInteger duration = [element[@"duration"][@"value"] intValue];
        
        if (seconds > duration) {
            NSLog(@"The point at index %lu is too low", mid);
            [self getPointAtTime:minutes withPoints:points withMin:mid + 1 withMax:max];
        
        } else if (seconds < duration) {
            NSLog(@"The point at index %lu is too high", mid);
            [self getPointAtTime:minutes withPoints:points withMin:min withMax:mid - 1];
        
        } else {
            CLLocation *location = (CLLocation *)points[mid];
            CLLocationCoordinate2D position = CLLocationCoordinate2DMake(location.coordinate.latitude, location.coordinate.longitude);
            GMSMarker *marker = [GMSMarker markerWithPosition:position];
            marker.map = self.mapView;
            [OTGNetworkRequest fetchDistanceBetweenStart:self.startLocation andEnd:(CLLocation *)points[mid] success:^(AFHTTPRequestOperation *operation, id responseObject) {
                NSDictionary *json = responseObject;
                NSDictionary *element = json[@"rows"][0][@"elements"][0];
                NSLog(@"%d", [element[@"duration"][@"value"] intValue]);
            }];
            return;
        }
    }];
}

- (void)keyboardWillHide:(NSNotification *)sender
{
    if ( [self.yelpSearchTextField isFirstResponder] || [self.timeTextField isFirstResponder] || [self.radiusTextField isFirstResponder] ) {
        self.keyboardBottomConstraint.constant = 0;
        self.keyboardTopConstraint.constant = 503;
    }
}

- (void)keyboardWillShow:(NSNotification *)sender
{
    if ( [self.yelpSearchTextField isFirstResponder] || [self.timeTextField isFirstResponder] || [self.radiusTextField isFirstResponder] ) {
        CGRect frame = [sender.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
        self.keyboardTopConstraint.constant = self.keyboardTopConstraint.constant - frame.size.height;
        self.keyboardBottomConstraint.constant = frame.size.height;
    }
}

@end

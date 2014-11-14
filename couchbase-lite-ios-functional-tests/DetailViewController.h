//
//  DetailViewController.h
//  couchbase-lite-ios-functional-tests
//
//  Created by Ashvinder Singh on 11/13/14.
//  Copyright (c) 2014 couchbase. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DetailViewController : UIViewController

@property (strong, nonatomic) id detailItem;
@property (weak, nonatomic) IBOutlet UILabel *detailDescriptionLabel;

@end


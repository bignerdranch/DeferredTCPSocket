//
//  private_helpers.h
//  DeferredTCPSocket
//
//  Created by John Gallagher on 9/12/14.
//  Copyright (c) 2014 Big Nerd Ranch. All rights reserved.
//

#import <Foundation/Foundation.h>

int fcntl_set_O_NONBLOCK(int fd);

dispatch_data_t get_dispatch_data_empty();

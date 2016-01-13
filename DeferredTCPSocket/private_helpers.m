//
//  private_helpers.m
//  DeferredTCPSocket
//
//  Created by John Gallagher on 9/12/14.
//  Copyright (c) 2014 Big Nerd Ranch. All rights reserved.
//

#import "private_helpers.h"

int fcntl_set_O_NONBLOCK(int fd) {
    return fcntl(fd, F_SETFL, O_NONBLOCK);
}

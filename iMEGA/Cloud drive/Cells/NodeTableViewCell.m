#import "NodeTableViewCell.h"

#import "MEGANodeList+MNZCategory.h"

#import "Helper.h"
#import "MEGAGetThumbnailRequestDelegate.h"
#import "MEGASdkManager.h"
#import "MEGAStore.h"
#import "NSDate+MNZCategory.h"
#import "NSString+MNZCategory.h"
#import "UIImageView+MNZCategory.h"

@implementation NodeTableViewCell

- (void)awakeFromNib {
    [super awakeFromNib];
    
    self.cancelButtonTrailingConstraint.constant =  ([[UIDevice currentDevice] iPadDevice] || [[UIDevice currentDevice] iPhonePlus]) ? 10 : 6;
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
    [super setEditing:editing animated:animated];
    
    BOOL editSingleRow = self.subviews.count == 3; // leading or trailing UITableViewCellEditControl doesn't appear
    
    if (editing) {
        self.moreButton.hidden = YES;
        if (!editSingleRow) {
            [UIView animateWithDuration:0.3 animations:^{
                self.separatorInset = UIEdgeInsetsMake(0, 102, 0, 0);
                [self layoutIfNeeded];
            }];
        }
    } else {
        [UIView animateWithDuration:0.3 animations:^{
            self.separatorInset = UIEdgeInsetsMake(0, 62, 0, 0);
            [self layoutIfNeeded];
        }];
        if ([[Helper downloadingNodes] objectForKey:self.node.base64Handle] == nil) {
            self.moreButton.hidden = self.recentActionBucket ? self.moreButton.hidden : NO;
        }
    }
}

- (void)configureCellForNode:(MEGANode *)node delegate:(id<MGSwipeTableCellDelegate>)delegate api:(MEGASdk *)api {
    self.node = node;
    
    BOOL isDownloaded = NO;
    if ([[Helper downloadingNodes] objectForKey:node.base64Handle]) {
        self.infoLabel.text = AMLocalizedString(@"queued", @"Text shown when one file has been selected to be downloaded but it's on the queue to be downloaded, it's pending for download");
        self.downloadingArrowImageView.hidden = self.cancelButton.hidden = self.downloadProgressView.hidden = NO;
        self.moreButton.hidden = YES;
    } else {
        isDownloaded = (node.isFile && [[MEGAStore shareInstance] offlineNodeWithNode:node]);
        
        self.downloadingArrowImageView.hidden =  self.cancelButton.hidden = self.downloadProgressView.hidden = YES;
        self.moreButton.hidden = NO;
    }
    
    if (node.isExported) {
        if (isDownloaded) {
            self.upImageView.image = [UIImage imageNamed:@"linked"];
            self.middleImageView.image = nil;
            self.downImageView.image = [Helper downloadedArrowImage];
        } else {
            self.upImageView.image = nil;
            self.middleImageView.image = [UIImage imageNamed:@"linked"];
            self.downImageView.image = nil;
        }
    } else {
        self.upImageView.image = nil;
        self.middleImageView.image = (isDownloaded) ? [Helper downloadedArrowImage] : nil;
        self.downImageView.image = nil;
    }
    
    if (node.hasThumbnail) {
        NSString *thumbnailFilePath = [Helper pathForNode:node inSharedSandboxCacheDirectory:@"thumbnailsV3"];
        if ([[NSFileManager defaultManager] fileExistsAtPath:thumbnailFilePath]) {
            self.thumbnailPlayImageView.hidden = !node.name.mnz_isVideoPathExtension;
            self.thumbnailImageView.image = [UIImage imageWithContentsOfFile:thumbnailFilePath];
        } else {
            MEGAGetThumbnailRequestDelegate *getThumbnailRequestDelegate = [[MEGAGetThumbnailRequestDelegate alloc] initWithCompletion:^(MEGARequest *request) {
                if (request.nodeHandle == self.node.handle) {
                    self.thumbnailPlayImageView.hidden = !node.name.mnz_isVideoPathExtension;
                    self.thumbnailImageView.image = [UIImage imageWithContentsOfFile:request.file];
                }
            }];
            [[MEGASdkManager sharedMEGASdk] getThumbnailNode:node destinationFilePath:thumbnailFilePath delegate:getThumbnailRequestDelegate];
            [self.thumbnailImageView mnz_imageForNode:node];
        }
    } else {
        [self.thumbnailImageView mnz_imageForNode:node];
    }
    
    if (!node.name.mnz_isVideoPathExtension) {
        self.thumbnailPlayImageView.hidden = YES;
    }
    
    self.nameLabel.text = node.name;
    if (node.isFile) {
        self.infoLabel.text = [Helper sizeAndDateForNode:node api:api];
        self.versionedImageView.hidden = ![[MEGASdkManager sharedMEGASdk] hasVersionsForNode:node];
    } else if (node.isFolder) {
        self.infoLabel.text = [Helper filesAndFoldersInFolderNode:node api:api];
        self.versionedImageView.hidden = YES;
    }
    
    if (@available(iOS 11.0, *)) {
        self.thumbnailImageView.accessibilityIgnoresInvertColors = YES;
        self.thumbnailPlayImageView.accessibilityIgnoresInvertColors = YES;
    } else {
        self.delegate = delegate;
    }
}

- (void)configureForRecentAction:(MEGARecentActionBucket *)recentActionBucket {
    self.recentActionBucket = recentActionBucket;
    NSArray *nodesArray = recentActionBucket.nodesList.mnz_nodesArrayFromNodeList;
    
    MEGANode *node = [nodesArray objectAtIndex:0];
    [self.thumbnailImageView mnz_setThumbnailByNode:node];
    self.thumbnailPlayImageView.hidden = node.hasThumbnail ? !node.name.mnz_isVideoPathExtension : YES;
    if (@available(iOS 11.0, *)) {
        self.thumbnailImageView.accessibilityIgnoresInvertColors = YES;
        self.thumbnailPlayImageView.accessibilityIgnoresInvertColors = YES;
    }
    
    NSString *title;
    if (nodesArray.count == 1) {
        title = node.name;
        
        self.moreButton.hidden = NO;
        self.disclosureIndicatorView.hidden = YES;
    } else if (nodesArray.count > 1) {
        NSString *tempString = AMLocalizedString(@"%1 and [A]%2 more[/A]", @"Title for a recent action shown in the webclient, see the attached image for context. Please ensure that the `%2 more` is inside the [A] tag as this will become a toggle to show the hidden content.");
        tempString = tempString.mnz_removeWebclientFormatters;
        tempString = [tempString stringByReplacingOccurrencesOfString:@"%1" withString:node.name];
        title = [tempString stringByReplacingOccurrencesOfString:@"%2" withString:[NSString stringWithFormat:@"%tu", nodesArray.count - 1]];
        
        self.moreButton.hidden = YES;
        self.disclosureIndicatorView.hidden = NO;
    }
    self.nameLabel.text = title;
    
    if (![recentActionBucket.userEmail isEqualToString:MEGASdkManager.sharedMEGASdk.myEmail]) {
        self.subtitleLabel.text = [NSString mnz_addedByInRecentActionBucket:recentActionBucket nodesArray:nodesArray];
        
        MEGAShareType shareType = [MEGASdkManager.sharedMEGASdk accessLevelForNode:node];
        self.incomingOrOutgoingImageView.image = (shareType == MEGAShareTypeAccessOwner) ? [UIImage imageNamed:@"mini_folder_outgoing"] : [UIImage imageNamed:@"mini_folder_incoming"];
    }
    
    MEGANode *parentNode = [MEGASdkManager.sharedMEGASdk nodeForHandle:recentActionBucket.parentHandle];
    self.infoLabel.text = [NSString stringWithFormat:@"%@ ・", parentNode.name];
    
    self.uploadOrVersionImageView.image = recentActionBucket.isUpdate ? [UIImage imageNamed:@"versioned"] : [UIImage imageNamed:@"recentUpload"];
    
    self.timeLabel.text = recentActionBucket.timestamp.mnz_formattedHourAndMinutes;
}

#pragma mark - IBActions

- (IBAction)cancelTransfer:(id)sender {
    NSNumber *transferTag = [[Helper downloadingNodes] objectForKey:[MEGASdk base64HandleForHandle:self.node.handle]];
    if ([[MEGASdkManager sharedMEGASdk] transferByTag:transferTag.integerValue] != nil) {
        [[MEGASdkManager sharedMEGASdk] cancelTransferByTag:transferTag.integerValue];
    } else {
        if ([[MEGASdkManager sharedMEGASdkFolder] transferByTag:transferTag.integerValue] != nil) {
            [[MEGASdkManager sharedMEGASdkFolder] cancelTransferByTag:transferTag.integerValue];
        }
    }
}

@end

#import <UIKit/UIKit.h>

#import "DisplayMode.h"

@class MEGANode;
@class MEGAUser;

@interface CloudDriveViewController : UIViewController

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *selectorViewHeightLayoutConstraint;
@property (nonatomic, getter=shouldHideSelectorView) BOOL hideSelectorView;

@property (nonatomic, strong) MEGANode *parentNode;
@property (nonatomic, strong) MEGAUser *user;
@property (nonatomic) DisplayMode displayMode;
@property (nonatomic, getter=isIncomingShareChildView) BOOL incomingShareChildView;
@property (nonatomic) BOOL homeQuickActionSearch;

@property (nonatomic, strong) MEGANodeList *nodes;
@property (nonatomic, strong) NSMutableArray *searchNodesArray;
@property (nonatomic, strong) NSMutableArray *selectedNodesArray;
@property (nonatomic, strong) NSMutableDictionary *nodesIndexPathMutableDictionary;

@property (strong, nonatomic) UISearchController *searchController;

@property (assign, nonatomic) BOOL allNodesSelected;

- (void)activateSearch;
- (void)presentUploadAlertController;
- (void)setViewEditing:(BOOL)editing;
- (void)updateNavigationBarTitle;
- (void)toolbarActionsForNodeArray:(NSArray *)nodeArray;
- (void)setToolbarActionsEnabled:(BOOL)boolValue;
- (void)showNode:(MEGANode *)node;
- (void)showCustomActionsForNode:(MEGANode *)node sender:(UIButton *)sender;

@end

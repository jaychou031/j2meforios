#import <Foundation/Foundation.h>

NSString *NJGameRMSPath(NSString *root, NSString *gameID);
BOOL NJClearGameData(NSString *root, NSString *gameID, NSError **error);
BOOL NJDeleteImportedGame(NSString *root, NSString *filename, NSError **error);

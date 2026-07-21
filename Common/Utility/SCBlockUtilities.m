//
//  SCBlockUtilities.m
//  SelfControl
//
//  Created by Charlie Stigler on 1/19/21.
//

#import "SCBlockUtilities.h"
#import "HostFileBlocker.h"
#import "PacketFilter.h"
#import <mach/mach_time.h>

NSTimeInterval const TRUSTED_ELAPSED_SYNC_THRESHOLD_SECS = 15.0;

@implementation SCBlockUtilities

+ (BOOL)anyBlockIsRunning {
    BOOL blockIsRunning = [SCBlockUtilities modernBlockIsRunning] || [SCBlockUtilities legacyBlockIsRunning];

    return blockIsRunning;
}

+ (BOOL)modernBlockIsRunning {
    SCSettings* settings = [SCSettings sharedSettings];
    
    return [settings boolForKey: @"BlockIsRunning"];
}

+ (BOOL)legacyBlockIsRunning {
    // first see if there's a legacy settings file from v3.x
    // which could be in any user's home folder
    NSError* homeDirErr = nil;
    NSArray<NSURL *>* homeDirectoryURLs = [SCMiscUtilities allUserHomeDirectoryURLs: &homeDirErr];
    if (homeDirectoryURLs != nil) {
        for (NSURL* homeDirURL in homeDirectoryURLs) {
            NSString* relativeSettingsPath = [NSString stringWithFormat: @"/Library/Preferences/%@", SCSettings.settingsFileName];
            NSURL* settingsFileURL = [homeDirURL URLByAppendingPathComponent: relativeSettingsPath isDirectory: NO];
            
            if ([SCMigrationUtilities legacyBlockIsRunningInSettingsFile: settingsFileURL]) {
                return YES;
            }
        }
    }

    // nope? OK, how about a lock file from pre-3.0?
    if ([SCMigrationUtilities legacyLockFileExists]) {
        return YES;
    }
    
    // we don't check defaults anymore, though pre-3.0 blocks did
    // have data stored there. That should be covered by the lockfile anyway
    
    return NO;
}

// returns YES if the block should have expired based on trusted elapsed time, or based on wall time for legacy blocks
+ (BOOL)currentBlockIsExpired {
    SCSettings* settings = [SCSettings sharedSettings];

    NSTimeInterval requiredDurationSecs = [[settings valueForKey: @"BlockRequiredDurationSeconds"] doubleValue];
    if (requiredDurationSecs > 0) {
        return [SCBlockUtilities trustedElapsedSecondsForCurrentBlockAndUpdateSettings: YES] >= requiredDurationSecs;
    }

    return [[settings valueForKey: @"BlockEndDate"] timeIntervalSinceNow] <= 0;
}

+ (NSTimeInterval)currentContinuousTimeSeconds {
    static mach_timebase_info_data_t timebaseInfo;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        mach_timebase_info(&timebaseInfo);
    });

    return ((NSTimeInterval)mach_continuous_time() * (NSTimeInterval)timebaseInfo.numer / (NSTimeInterval)timebaseInfo.denom) / 1000000000.0;
}

+ (void)startTrustedElapsedTrackingWithRequiredDuration:(NSTimeInterval)requiredDurationSecs {
    SCSettings* settings = [SCSettings sharedSettings];

    [settings setValue: @(MAX(requiredDurationSecs, 0)) forKey: @"BlockRequiredDurationSeconds"];
    [settings setValue: @0 forKey: @"BlockTrustedElapsedSeconds"];
    [settings setValue: @([SCBlockUtilities currentContinuousTimeSeconds]) forKey: @"BlockLastContinuousTimeSeconds"];
}

+ (NSTimeInterval)trustedElapsedSecondsForCurrentBlockAndUpdateSettings:(BOOL)updateSettings {
    SCSettings* settings = [SCSettings sharedSettings];

    NSTimeInterval elapsedSecs = [[settings valueForKey: @"BlockTrustedElapsedSeconds"] doubleValue];
    NSTimeInterval lastContinuousSecs = [[settings valueForKey: @"BlockLastContinuousTimeSeconds"] doubleValue];
    NSTimeInterval currentContinuousSecs = [SCBlockUtilities currentContinuousTimeSeconds];

    if (lastContinuousSecs <= 0) {
        lastContinuousSecs = currentContinuousSecs;
    }

    NSTimeInterval deltaSecs = currentContinuousSecs - lastContinuousSecs;
    if (deltaSecs > 0) {
        elapsedSecs += deltaSecs;
    }

    if (updateSettings && (deltaSecs < 0 || deltaSecs >= TRUSTED_ELAPSED_SYNC_THRESHOLD_SECS)) {
        [settings setValue: @(elapsedSecs) forKey: @"BlockTrustedElapsedSeconds"];
        [settings setValue: @(currentContinuousSecs) forKey: @"BlockLastContinuousTimeSeconds"];
        [settings synchronizeSettings];
    }

    return elapsedSecs;
}

+ (BOOL)blockRulesFoundOnSystem {
    return [PacketFilter blockFoundInPF] || [HostFileBlocker blockFoundInHostsFile];
}

+ (void) removeBlockFromSettings {
    SCSettings* settings = [SCSettings sharedSettings];
    [settings setValue: @NO forKey: @"BlockIsRunning"];
    [settings setValue: nil forKey: @"BlockEndDate"];
    [settings setValue: nil forKey: @"BlockRequiredDurationSeconds"];
    [settings setValue: nil forKey: @"BlockTrustedElapsedSeconds"];
    [settings setValue: nil forKey: @"BlockLastContinuousTimeSeconds"];
    [settings setValue: nil forKey: @"ActiveBlocklist"];
    [settings setValue: nil forKey: @"ActiveBlockAsWhitelist"];
}

@end

//
//  APHDashboardViewController.m 
//  mPower 
// 
// Copyright (c) 2015, Sage Bionetworks. All rights reserved. 
// 
// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:
// 
// 1.  Redistributions of source code must retain the above copyright notice, this
// list of conditions and the following disclaimer.
// 
// 2.  Redistributions in binary form must reproduce the above copyright notice, 
// this list of conditions and the following disclaimer in the documentation and/or 
// other materials provided with the distribution. 
// 
// 3.  Neither the name of the copyright holder(s) nor the names of any contributors 
// may be used to endorse or promote products derived from this software without 
// specific prior written permission. No license is granted to the trademarks of 
// the copyright holders even if such marks are included in this software. 
// 
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" 
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE 
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE 
// FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL 
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR 
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER 
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, 
// OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE 
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. 
// 
 
/* Controllers */
#import "APHDashboardViewController.h"
#import "APHDashboardEditViewController.h"
#import "APHDashboardGraphTableViewCell.h"
#import "APHDataKeys.h"
#import "APHLocalization.h"
#import "APHMedicationTrackerTask.h"
#import "APHMedicationTrackerViewController.h"
#import "APHTableViewDashboardGraphItem.h"
#import "APHScoring.h"
#import "APHTremorTaskViewController.h"
#import "APHWalkingTaskViewController.h"
#import "APHAppDelegate.h"
#import "APHMedicationTracker.h"
#import "APHWebViewStepViewController.h"
@import BridgeAppSDK;


static NSString * const kAPCBasicTableViewCellIdentifier          = @"APCBasicTableViewCell";
static NSString * const kAPCRightDetailTableViewCellIdentifier    = @"APCRightDetailTableViewCell";
static NSString * const kAPHDashboardGraphTableViewCellIdentifier = @"APHDashboardGraphTableViewCell";

@interface APCDashboardViewController (Private) <UIGestureRecognizerDelegate>
@property (nonatomic, strong) APCPresentAnimator *presentAnimator;
@property (nonatomic, strong) NSMutableArray *lineCharts;
@end
static NSString * const kAPHMonthlyReportTaskIdentifier        = @"Monthly Report";
static NSString * const kAPHMonthlyReportHTMLStepIdentifier    = @"report";

@interface APHDashboardViewController ()<UIViewControllerTransitioningDelegate, APCCorrelationsSelectorDelegate, ORKTaskViewControllerDelegate>

@property (weak, nonatomic) IBOutlet UIButton *monthlyReportButton;

@property (nonatomic, strong) NSArray *rowItemsOrder;

@property (nonatomic, strong) APHScoring *tapRightScoring;
@property (nonatomic, strong) APHScoring *tapLeftScoring;
@property (nonatomic, strong) APHScoring *gaitScoring;
@property (nonatomic, strong) APCScoring *stepScoring;
@property (nonatomic, strong) APHScoring *phonationScoring;
@property (nonatomic, strong) APHScoring *tremorScoring;
@property (nonatomic, strong) APCScoring *moodScoring;
@property (nonatomic, strong) APCScoring *energyScoring;
@property (nonatomic, strong) APCScoring *exerciseScoring;
@property (nonatomic, strong) APCScoring *sleepScoring;
@property (nonatomic, strong) APCScoring *cognitiveScoring;
@property (nonatomic, strong) APCScoring *customScoring;

@end

@implementation APHDashboardViewController

#pragma mark - Init

- (id)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder]) {
        
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        _rowItemsOrder = [NSMutableArray arrayWithArray:[defaults objectForKey:kAPCDashboardRowItemsOrder]];
        
        if (!_rowItemsOrder.count) {
            _rowItemsOrder = [self allRowItems];
            
            [defaults setObject:[NSArray arrayWithArray:_rowItemsOrder] forKey:kAPCDashboardRowItemsOrder];
            [defaults synchronize];
            
        }
        
        self.title = NSLocalizedStringWithDefaultValue(@"APH_DASHBOARD_TITLE", nil, APHLocaleBundle(), @"Dashboard", @"Title for the Dashboard view controller.");
    }
    
    return self;
}

#pragma mark - LifeCycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.monthlyReportButton.tintColor = [UIColor appTertiaryBlueColor];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(prepareCorrelatedScoring) name:APCSchedulerUpdatedScheduledTasksNotification object:nil];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    
    [self prepareScoringObjects];
    [self prepareData];

}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self updateRowItemsOrder];
    
    [self prepareScoringObjects];
    [self prepareData];
    
    self.monthlyReportButton.hidden = [self medicationTrackingHidden];
}

// Hide if this is a control group or the user does not take a tracked medication
- (BOOL)medicationTrackingHidden {
    APCDataGroupsManager *dataGroupsManager = [[APHAppDelegate sharedAppDelegate] dataGroupsManagerForUser:nil];
    return (dataGroupsManager.isStudyControlGroup || [[APHMedicationTrackerDataStore sharedStore] hasNoTrackedItems]);
}

- (void)updateVisibleRowsInTableView:(NSNotification *) __unused notification
{
    [self prepareData];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Data

// list of all the valid row items, in what will be the default order until the user rearranges them
- (NSArray<NSNumber *> *)allRowItems
{
    NSMutableArray<NSNumber *> *allRowItems =
    [@[
      //@(kAPHDashboardItemTypeCorrelation), // Hide correlation BRIDGE-1214 syoung 03/16/2016
      @(kAPHDashboardItemTypeSteps),
      @(kAPHDashboardItemTypeIntervalTappingRight),
      @(kAPHDashboardItemTypeIntervalTappingLeft),
      @(kAPHDashboardItemTypePhonation),
      @(kAPHDashboardItemTypeGait),
      //@(kAPHDashboardItemTypeTremor), // Hide the tremor module until analyzed for scoring. syoung 03/03/2016
      @(kAPHDashboardItemTypeDailyMood),
      @(kAPHDashboardItemTypeDailyEnergy),
      @(kAPHDashboardItemTypeDailyExercise),
      @(kAPHDashboardItemTypeDailySleep),
      @(kAPHDashboardItemTypeDailyCognitive)
      ] mutableCopy];
    
    APCAppDelegate *appDelegate = (APCAppDelegate *)[UIApplication sharedApplication].delegate;
    NSString *customSurveyQuestion = appDelegate.dataSubstrate.currentUser.customSurveyQuestion;
    if (customSurveyQuestion != nil && ![customSurveyQuestion isEqualToString:@""]) {
        [allRowItems addObject:@(kAPHDashboardItemTypeDailyCustom)];
    }
    
    return [allRowItems copy];
}

// Make sure self.rowItemsOrder contains all, and only, the available items
// (this is mostly important when a new release contains new dashboard items, and when the user adds or
// removes their custom daily survey question)
- (void)updateRowItemsOrder
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    self.rowItemsOrder = [defaults objectForKey:kAPCDashboardRowItemsOrder];
    NSMutableArray *itemsOrder = [self.rowItemsOrder mutableCopy];
    
    NSArray *allRowItems = [self allRowItems];
    NSMutableArray *newItems = [NSMutableArray array];
    for (NSNumber *item in allRowItems) {
        if (![itemsOrder containsObject:item]) {
            [newItems addObject:item];
        }
    }
    
    [itemsOrder addObjectsFromArray:newItems];
    
    NSMutableArray *oldItems = [NSMutableArray array];
    for (NSNumber *item in _rowItemsOrder) {
        if (![allRowItems containsObject:item]) {
            [oldItems addObject:item];
        }
    }
    
    [itemsOrder removeObjectsInArray:oldItems];
    
    // update locally and in user defaults only if it changed
    if (newItems.count || oldItems.count) {
        self.rowItemsOrder = [itemsOrder copy];
        [defaults setObject:self.rowItemsOrder forKey:kAPCDashboardRowItemsOrder];
        [defaults synchronize];
    }
}

- (void)prepareScoringObjects
{
    self.tapRightScoring = [[APHScoring alloc] initWithTask:APHTappingActivitySurveyIdentifier
                                               numberOfDays:-kNumberOfDaysToDisplay
                                                   valueKey:APHRightSummaryNumberOfRecordsKey
                                                 latestOnly:NO];
    self.tapRightScoring.caption = NSLocalizedStringWithDefaultValue(@"APH_TAPPING_RIGHT_CAPTION", nil, APHLocaleBundle(), @"Tapping - Right", @"Dashboard caption for results of right hand tapping activity.");

    self.tapLeftScoring = [[APHScoring alloc] initWithTask:APHTappingActivitySurveyIdentifier
                                              numberOfDays:-kNumberOfDaysToDisplay
                                                  valueKey:APHLeftSummaryNumberOfRecordsKey
                                                latestOnly:NO];
    self.tapLeftScoring.caption = NSLocalizedStringWithDefaultValue(@"APH_TAPPING_LEFT_CAPTION", nil, APHLocaleBundle(), @"Tapping - Left", @"Dashboard caption for results of left hand tapping activity.");
    
    self.gaitScoring = [[APHScoring alloc] initWithTask:APHWalkingActivitySurveyIdentifier
                                           numberOfDays:-kNumberOfDaysToDisplay
                                               valueKey:kGaitScoreKey
                                             latestOnly:NO];
    self.gaitScoring.caption = NSLocalizedStringWithDefaultValue(@"APH_WALKING_CAPTION", nil, APHLocaleBundle(), @"Gait", @"Dashboard caption for results of walking activity.");

    self.phonationScoring = [[APHScoring alloc] initWithTask:APHVoiceActivitySurveyIdentifier
                                                numberOfDays:-kNumberOfDaysToDisplay
                                                    valueKey:APHPhonationScoreSummaryOfRecordsKey
                                                  latestOnly:NO];
    self.phonationScoring.caption = NSLocalizedStringWithDefaultValue(@"APH_VOICE_CAPTION", nil, APHLocaleBundle(), @"Voice", @"Dashboard caption for results of voice activity.");
    
    HKQuantityType *hkQuantity = [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierStepCount];
    self.stepScoring = [[APHScoring alloc] initWithHealthKitQuantityType:hkQuantity
                                                                    unit:[HKUnit countUnit]
                                                            numberOfDays:-kNumberOfDaysToDisplay];
    self.stepScoring.caption = NSLocalizedStringWithDefaultValue(@"APH_STEPS_CAPTION", nil, APHLocaleBundle(), @"Steps", @"Dashboard caption for results of steps score.");
    
    self.tremorScoring = [[APHScoring alloc] initWithTask:APHTremorActivitySurveyIdentifier
                                             numberOfDays:-kNumberOfDaysToDisplay
                                                 valueKey:kTremorScoreKey];
    self.tremorScoring.caption = NSLocalizedStringWithDefaultValue(@"APH_TREMOR_CAPTION", nil, APHLocaleBundle(), @"Tremor", @"Dashboard caption for results of tremor score.");
    
    self.moodScoring = [self scoringForValueKey:@"moodsurvey103"];
    self.moodScoring.customMinimumPoint = 1.0;
    self.moodScoring.customMaximumPoint = 5.0;
    self.moodScoring.caption = NSLocalizedStringWithDefaultValue(@"APH_DAILY_MOOD_CAPTION", nil, APHLocaleBundle(), @"Mood", @"Dashboard caption for daily mood report");
    
    self.energyScoring = [self scoringForValueKey:@"moodsurvey104"];
    self.energyScoring.customMinimumPoint = 1.0;
    self.energyScoring.customMaximumPoint = 5.0;
    self.energyScoring.caption = NSLocalizedStringWithDefaultValue(@"APH_DAILY_ENERGY_CAPTION", nil, APHLocaleBundle(), @"Energy Level", @"Dashboard caption for daily energy report");
    
    self.exerciseScoring = [self scoringForValueKey:@"moodsurvey106"];
    self.exerciseScoring.customMinimumPoint = 1.0;
    self.exerciseScoring.customMaximumPoint = 5.0;
    self.exerciseScoring.caption = NSLocalizedStringWithDefaultValue(@"APH_DAILY_EXERCISE_CAPTION", nil, APHLocaleBundle(), @"Exercise Level", @"Dashboard caption for daily exercise report");
    
    self.sleepScoring = [self scoringForValueKey:@"moodsurvey105"];
    self.sleepScoring.customMinimumPoint = 1.0;
    self.sleepScoring.customMaximumPoint = 5.0;
    self.sleepScoring.caption = NSLocalizedStringWithDefaultValue(@"APH_DAILY_SLEEP_CAPTION", nil, APHLocaleBundle(), @"Sleep Quality", @"Dashboard caption for daily sleep quality report");
    
    self.cognitiveScoring = [self scoringForValueKey:@"moodsurvey102"];
    self.cognitiveScoring.customMinimumPoint = 1.0;
    self.cognitiveScoring.customMaximumPoint = 5.0;
    self.cognitiveScoring.caption = NSLocalizedStringWithDefaultValue(@"APH_DAILY_THINKING_CAPTION", nil, APHLocaleBundle(), @"Thinking", @"Dashboard caption for daily mental clarity report");
    
    self.customScoring = [self scoringForValueKey:@"moodsurvey107"];
    self.customScoring.customMinimumPoint = 1.0;
    self.customScoring.customMaximumPoint = 5.0;
    self.customScoring.caption = NSLocalizedStringWithDefaultValue(@"APH_DAILY_CUSTOM_CAPTION", nil, APHLocaleBundle(), @"Custom Question", @"Dashboard caption for daily user-defined custom question report");

    if (!self.correlatedScoring) {
        [self prepareCorrelatedScoring];
    }
}

- (APHScoring *)scoringForValueKey:(NSString *)valueKey
{
    return [[APHScoring alloc] initWithTask:APHDailySurveyIdentifier
                               numberOfDays:-kNumberOfDaysToDisplay
                                   valueKey:valueKey
                                 latestOnly:NO];
}

- (void)prepareCorrelatedScoring{

    self.correlatedScoring = [[APHScoring alloc] initWithTask:APHWalkingActivitySurveyIdentifier
                                                 numberOfDays:-kNumberOfDaysToDisplay
                                                     valueKey:kGaitScoreKey];
    
    HKQuantityType *hkQuantity = [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierStepCount];
    [self.correlatedScoring correlateWithScoringObject:[[APHScoring alloc] initWithHealthKitQuantityType:hkQuantity
                                                                                                    unit:[HKUnit countUnit]
                                                                                            numberOfDays:-kNumberOfDaysToDisplay]];
    
    self.correlatedScoring.caption = NSLocalizedStringWithDefaultValue(@"APH_DATA_CORRELATION_CAPTION", nil, APHLocaleBundle(), @"Data Correlation", @"Dashboard caption for data correlation.");
    
    //default series
    self.correlatedScoring.series1Name = self.gaitScoring.caption;
    self.correlatedScoring.series2Name = self.stepScoring.caption;
}

- (void)prepareData
{
    [self.items removeAllObjects];
    
    {
        NSMutableArray *rowItems = [NSMutableArray new];
        
        NSUInteger allScheduledTasks = ((APCAppDelegate *)[UIApplication sharedApplication].delegate).dataSubstrate.countOfTotalRequiredTasksForToday;
        NSUInteger completedScheduledTasks = ((APCAppDelegate *)[UIApplication sharedApplication].delegate).dataSubstrate.countOfTotalCompletedTasksForToday;
        
        {
            APCTableViewDashboardProgressItem *item = [APCTableViewDashboardProgressItem new];
            item.reuseIdentifier = kAPCDashboardProgressTableViewCellIdentifier;
            item.editable = NO;
            item.progress = (CGFloat)completedScheduledTasks/allScheduledTasks;
            item.caption = NSLocalizedStringWithDefaultValue(@"APH_ACTIVITY_COMPLETION_CAPTION", nil, APHLocaleBundle(), @"Activity Completion", @"Dashboard caption for the activities completed.");

            item.info = NSLocalizedStringWithDefaultValue(@"APH_DASHBOARD_ACTIVITY_COMPLETION_INFO", nil, APHLocaleBundle(), @"This graph shows the percent of Today's activities that you completed. You can complete more of your tasks in the Activities tab.", @"Dashboard tooltip item info text for Activity Completion in Parkinson");
            
            APCTableViewRow *row = [APCTableViewRow new];
            row.item = item;
            row.itemType = kAPCTableViewDashboardItemTypeProgress;
            [rowItems addObject:row];
        }
        
        NSString *detailMinMaxFormat = NSLocalizedStringWithDefaultValue(@"APH_DASHBOARD_MINMAX_DETAIL", nil, APHLocaleBundle(), @"Min: %@  Max: %@", @"Format of detail text showing participant's minimum and maximum scores on relevant activity, to be filled in with their minimum and maximum scores");
        NSString *detailAvgFormat = NSLocalizedStringWithDefaultValue(@"APH_DASHBOARD_AVG_DETAIL", nil, APHLocaleBundle(), @"Average: %@", @"Format of detail text showing participant's average score on relevant activity, to be filled in with their average score");
        
        for (NSNumber *typeNumber in self.rowItemsOrder) {
            
            APHDashboardItemType rowType = typeNumber.integerValue;
            
            switch (rowType) {
                    
                case kAPHDashboardItemTypeCorrelation:{
                    
                    APHTableViewDashboardGraphItem *item = [APHTableViewDashboardGraphItem new];
                    item.caption = NSLocalizedStringWithDefaultValue(@"APH_DATA_CORRELATION_CAPTION", nil, APHLocaleBundle(), @"Data Correlation", @"Dashboard caption for data correlation.");
                    item.graphData = self.correlatedScoring;
                    item.graphType = kAPCDashboardGraphTypeLine;
                    item.reuseIdentifier = kAPHDashboardGraphTableViewCellIdentifier;
                    item.editable = YES;
                    item.tintColor = [UIColor appTertiaryYellowColor];
                    
                    NSString *infoFormat = NSLocalizedStringWithDefaultValue(@"APH_DASHBOARD_CORRELATION_INFO", nil, APHLocaleBundle(), @"This chart plots the index of your %@ against the index of your %@. For more comparisons, click the series name.", @"Format of caption for correlation plot comparing indices of two series, to be filled in with the names of the series being compared.");
                    item.info = [NSString stringWithFormat:infoFormat, self.correlatedScoring.series1Name, self.correlatedScoring.series2Name];
                    item.detailText = @"";
                    item.legend = [APHTableViewDashboardGraphItem legendForSeries1:self.correlatedScoring.series1Name series2:self.correlatedScoring.series2Name];
                    APCTableViewRow *row = [APCTableViewRow new];
                    row.item = item;
                    row.itemType = rowType;
                    [rowItems addObject:row];
                    
                }
                    break;
                    
                case kAPHDashboardItemTypeIntervalTappingRight:
                case kAPHDashboardItemTypeIntervalTappingLeft:
                {
                    APCScoring *tapScoring = (rowType == kAPHDashboardItemTypeIntervalTappingRight) ? self.tapRightScoring : self.tapLeftScoring;
                    APHTableViewDashboardGraphItem *item = [APHTableViewDashboardGraphItem new];
                    item.caption = tapScoring.caption;
                    item.taskId = APHTappingActivitySurveyIdentifier;
                    item.graphData = tapScoring;
                    item.graphType = APHDashboardGraphTypeDiscrete;
                    
                    double avgValue = [[tapScoring averageDataPoint] doubleValue];
                    
                    if (avgValue > 0) {
                        item.detailText = [NSString stringWithFormat:detailMinMaxFormat,
                                           APHLocalizedStringFromNumber([tapScoring minimumDataPoint]), APHLocalizedStringFromNumber([tapScoring maximumDataPoint])];
                    }
                    
                    item.reuseIdentifier = kAPHDashboardGraphTableViewCellIdentifier;
                    item.editable = YES;
                    item.tintColor = [UIColor colorForTaskId:item.taskId];
					item.showMedicationLegend = ![self medicationTrackingHidden];
                
                    item.info = NSLocalizedStringWithDefaultValue(@"APH_DASHBOARD_TAPPING_INFO", nil, APHLocaleBundle(), @"This plot shows your finger tapping speed each day as measured by the Tapping Interval Activity. The length and position of each vertical bar represents the range in the number of taps you made in 20 seconds for a given day. Any differences in length or position over time reflect variations and trends in your tapping speed, which may reflect variations and trends in your symptoms.", @"Dashboard tooltip item info text for Tapping in Parkinson");
                    
                    APCTableViewRow *row = [APCTableViewRow new];
                    row.item = item;
                    row.itemType = rowType;
                    [rowItems addObject:row];

                }
                    break;
                case kAPHDashboardItemTypeGait:
                {
                    APHTableViewDashboardGraphItem *item = [APHTableViewDashboardGraphItem new];
                    item.caption = self.gaitScoring.caption;
                    item.taskId = APHWalkingActivitySurveyIdentifier;
                    item.graphData = self.gaitScoring;
                    item.graphType = APHDashboardGraphTypeDiscrete;
                    
                    double avgValue = [[self.gaitScoring averageDataPoint] doubleValue];
                    
                    if (avgValue > 0) {
                        item.detailText = [NSString stringWithFormat:detailMinMaxFormat,
                                           APHLocalizedStringFromNumber([self.gaitScoring minimumDataPoint]), APHLocalizedStringFromNumber([self.gaitScoring maximumDataPoint])];
                    }
                    
                    item.reuseIdentifier = kAPHDashboardGraphTableViewCellIdentifier;
                    item.editable = YES;
                    item.tintColor = [UIColor colorForTaskId:item.taskId];
                    item.showMedicationLegend = ![self medicationTrackingHidden];
                    
                    item.info = NSLocalizedStringWithDefaultValue(@"APH_DASHBOARD_WALKING_INFO", nil, APHLocaleBundle(), @"This plot combines several accelerometer-based measures for the Walking Activity. The length and position of each vertical bar represents the range of measures for a given day. Any differences in length or position over time reflect variations and trends in your Walking measure, which may reflect variations and trends in your symptoms.", @"Dashboard tooltip item info text for Gait in Parkinson");
                    
                    APCTableViewRow *row = [APCTableViewRow new];
                    row.item = item;
                    row.itemType = rowType;
                    [rowItems addObject:row];
                }
                    break;
                case kAPHDashboardItemTypePhonation:
                {
                    APHTableViewDashboardGraphItem *item = [APHTableViewDashboardGraphItem new];
                    item.caption = self.phonationScoring.caption;
                    item.taskId = APHVoiceActivitySurveyIdentifier;
                    item.graphData = self.phonationScoring;
                    item.graphType = APHDashboardGraphTypeDiscrete;
                    
                    double avgValue = [[self.phonationScoring averageDataPoint] doubleValue];
                    
                    if (avgValue > 0) {
                        item.detailText = [NSString stringWithFormat:detailMinMaxFormat,
                                           APHLocalizedStringFromNumber([self.phonationScoring minimumDataPoint]), APHLocalizedStringFromNumber([self.phonationScoring maximumDataPoint])];
                    }
                    
                    item.reuseIdentifier = kAPHDashboardGraphTableViewCellIdentifier;
                    item.editable = YES;
                    item.tintColor = [UIColor colorForTaskId:item.taskId];
                    item.showMedicationLegend = ![self medicationTrackingHidden];
                    
                    item.info = NSLocalizedStringWithDefaultValue(@"APH_DASHBOARD_VOICE_INFO", nil, APHLocaleBundle(), @"This plot combines several microphone-based measures as a single score for the Voice Activity. The length and position of each vertical bar represents the range of measures for a given day. Any differences in length or position over time reflect variations and trends in your Voice measure, which may reflect variations and trends in your symptoms.", @"Dashboard tooltip item info text for Voice in Parkinson");
                    
                    APCTableViewRow *row = [APCTableViewRow new];
                    row.item = item;
                    row.itemType = rowType;
                    [rowItems addObject:row];
                }
                    break;
                    
                case kAPHDashboardItemTypeSteps:
                {
                    APHTableViewDashboardGraphItem  *item = [APHTableViewDashboardGraphItem new];
                    item.caption = self.stepScoring.caption;
                    item.graphData = self.stepScoring;
                    
                    double avgValue = [[self.stepScoring averageDataPoint] doubleValue];
                    
                    if (avgValue > 0) {
                        item.detailText = [NSString stringWithFormat:detailAvgFormat,
                                           APHLocalizedStringFromNumber([self.stepScoring averageDataPoint])];
                    }
                    
                    item.reuseIdentifier = kAPHDashboardGraphTableViewCellIdentifier;
                    item.editable = YES;
                    item.tintColor = [UIColor appTertiaryGreenColor];
                    
                    item.info = NSLocalizedStringWithDefaultValue(@"APH_DASHBOARD_STEPS_INFO", nil, APHLocaleBundle(), @"This graph shows how many steps you took each day, according to your phone's motion sensors. Remember that for this number to be accurate, you should have the phone on you as frequently as possible.", @"Dashboard tooltip item info text for Steps in Parkinson");
                    
                    APCTableViewRow *row = [APCTableViewRow new];
                    row.item = item;
                    row.itemType = rowType;
                    [rowItems addObject:row];
                }
                    break;
                    
                case kAPHDashboardItemTypeTremor:
                {
                    APCTableViewDashboardGraphItem  *item = [APCTableViewDashboardGraphItem new];
                    item.caption = self.tremorScoring.caption;
                    item.graphData = self.tremorScoring;
                    item.graphType = APHDashboardGraphTypeDiscrete;
                    
                    double avgValue = [[self.tremorScoring averageDataPoint] doubleValue];
                    
                    if (avgValue > 0) {
                        item.detailText = [NSString stringWithFormat:detailAvgFormat,
                                           APHLocalizedStringFromNumber([self.tremorScoring averageDataPoint])];
                    }
                    
                    item.reuseIdentifier = kAPCDashboardGraphTableViewCellIdentifier;
                    item.editable = YES;
                    item.tintColor = [UIColor colorForTaskId:APHTremorActivitySurveyIdentifier];
                    
                    item.info = NSLocalizedStringWithDefaultValue(@"APH_DASHBOARD_TREMOR_INFO", nil, APHLocaleBundle(), @"This plot shows the score you received each day for the Tremor Test.", @"Dashboard tooltip item info text for Tremor Test in Parkinson");
                    
                    APCTableViewRow *row = [APCTableViewRow new];
                    row.item = item;
                    row.itemType = rowType;
                    [rowItems addObject:row];
                }
                    break;
                    
                case kAPHDashboardItemTypeDailyMood:{
                    
                    APHTableViewDashboardGraphItem *item = [APHTableViewDashboardGraphItem new];
                    item.caption = self.moodScoring.caption;
                    item.graphData = self.moodScoring;
                    item.graphType = kAPCDashboardGraphTypeDiscrete;
                    item.reuseIdentifier = kAPHDashboardGraphTableViewCellIdentifier;
                    item.editable = YES;
                    item.tintColor = [UIColor appTertiaryYellowColor];
                    
                    item.minimumImage = [UIImage imageNamed:@"MoodSurveyMood-5g"];
                    item.maximumImage = [UIImage imageNamed:@"MoodSurveyMood-1g"];
                    
                    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"datasetValueKey != %@", @(NSNotFound)];
                    NSArray *scoringObjects = [[self.moodScoring allObjects] filteredArrayUsingPredicate:predicate];
                    
                    if ([[self.moodScoring averageDataPoint] doubleValue] > 0 && scoringObjects.count > 1) {
                        item.averageImage = [UIImage imageNamed:[NSString stringWithFormat:@"MoodSurveyMood-%0.0fg", (double) 6 - [[self.moodScoring averageDataPoint] doubleValue]]];
                        item.detailText = [NSString stringWithFormat:detailAvgFormat,
                                           APHLocalizedStringFromNumber([self.moodScoring averageDataPoint])];
                    }
                    
                    item.info = NSLocalizedStringWithDefaultValue(@"APH_DASHBOARD_DAILY_MOOD_INFO", nil, APHLocaleBundle(), @"This graph shows your answers to the daily check-in questions for mood each day. ", @"Dashboard tooltip item info text for daily check-in Mood in Parkinson");
                    
                    APCTableViewRow *row = [APCTableViewRow new];
                    row.item = item;
                    row.itemType = rowType;
                    [rowItems addObject:row];
                }
                    break;
                    
                case kAPHDashboardItemTypeDailyEnergy:{
                    
                    APHTableViewDashboardGraphItem *item = [APHTableViewDashboardGraphItem new];
                    item.caption = self.energyScoring.caption;
                    item.graphData = self.energyScoring;
                    item.graphType = APHDashboardGraphTypeDiscrete;
                    item.reuseIdentifier = kAPHDashboardGraphTableViewCellIdentifier;
                    item.editable = YES;
                    item.tintColor = [UIColor appTertiaryGreenColor];
                    
                    item.minimumImage = [UIImage imageNamed:@"MoodSurveyEnergy-5g"];
                    item.maximumImage = [UIImage imageNamed:@"MoodSurveyEnergy-1g"];
                    
                    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"datasetValueKey != %@", @(NSNotFound)];
                    NSArray *scoringObjects = [[self.moodScoring allObjects] filteredArrayUsingPredicate:predicate];
                    
                    if ([[self.energyScoring averageDataPoint] doubleValue] > 0 && scoringObjects.count > 1) {
                        item.averageImage = [UIImage imageNamed:[NSString stringWithFormat:@"MoodSurveyEnergy-%0.0fg", (double) 6 - [[self.energyScoring averageDataPoint] doubleValue]]];
                        item.detailText = [NSString stringWithFormat:detailAvgFormat,
                                           APHLocalizedStringFromNumber([self.energyScoring averageDataPoint])];
                    }
                    
                    
                    item.info = NSLocalizedStringWithDefaultValue(@"APH_DASHBOARD_DAILY_ENERGY_INFO", nil, APHLocaleBundle(), @"This graph shows your answers to the daily check-in questions for energy each day.", @"Dashboard tooltip item info text for daily check-in Energy in Parkinson");
                    
                    APCTableViewRow *row = [APCTableViewRow new];
                    row.item = item;
                    row.itemType = rowType;
                    [rowItems addObject:row];
                }
                    break;
                    
                case kAPHDashboardItemTypeDailyExercise:{
                    
                    APHTableViewDashboardGraphItem *item = [APHTableViewDashboardGraphItem new];
                    item.caption = self.exerciseScoring.caption;
                    item.graphData = self.exerciseScoring;
                    item.graphType = APHDashboardGraphTypeDiscrete;
                    item.reuseIdentifier = kAPHDashboardGraphTableViewCellIdentifier;
                    item.editable = YES;
                    item.tintColor = [UIColor appTertiaryYellowColor];
                    
                    item.minimumImage = [UIImage imageNamed:@"MoodSurveyExercise-5g"];
                    item.maximumImage = [UIImage imageNamed:@"MoodSurveyExercise-1g"];
                    
                    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"datasetValueKey != %@", @(NSNotFound)];
                    NSArray *scoringObjects = [[self.moodScoring allObjects] filteredArrayUsingPredicate:predicate];
                    
                    if ([[self.exerciseScoring averageDataPoint] doubleValue] > 0 && scoringObjects.count > 1) {
                        item.averageImage = [UIImage imageNamed:[NSString stringWithFormat:@"MoodSurveyExercise-%0.0fg", (double) 6 - [[self.exerciseScoring averageDataPoint] doubleValue]]];
                        item.detailText = [NSString stringWithFormat:detailAvgFormat,
                                           APHLocalizedStringFromNumber([self.exerciseScoring averageDataPoint])];
                    }
                    
                    
                    item.info = NSLocalizedStringWithDefaultValue(@"APH_DASHBOARD_DAILY_EXERCISE_INFO", nil, APHLocaleBundle(), @"This graph shows your answers to the daily check-in questions for exercise each day.", @"Dashboard tooltip item info text for daily check-in Exercise in Parkinson");
                    
                    APCTableViewRow *row = [APCTableViewRow new];
                    row.item = item;
                    row.itemType = rowType;
                    [rowItems addObject:row];
                }
                    break;
                    
                case kAPHDashboardItemTypeDailySleep:{
                    
                    APHTableViewDashboardGraphItem *item = [APHTableViewDashboardGraphItem new];
                    item.caption = self.sleepScoring.caption;
                    item.graphData = self.sleepScoring;
                    item.graphType = APHDashboardGraphTypeDiscrete;
                    item.reuseIdentifier = kAPHDashboardGraphTableViewCellIdentifier;
                    item.editable = YES;
                    item.tintColor = [UIColor appTertiaryPurpleColor];
                    
                    item.minimumImage = [UIImage imageNamed:@"MoodSurveySleep-5g"];
                    item.maximumImage = [UIImage imageNamed:@"MoodSurveySleep-1g"];
                    
                    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"datasetValueKey != %@", @(NSNotFound)];
                    NSArray *scoringObjects = [[self.moodScoring allObjects] filteredArrayUsingPredicate:predicate];
                    
                    if ([[self.sleepScoring averageDataPoint] doubleValue] > 0 && scoringObjects.count > 1) {
                        item.averageImage = [UIImage imageNamed:[NSString stringWithFormat:@"MoodSurveySleep-%0.0fg", (double) 6 - [[self.sleepScoring averageDataPoint] doubleValue]]];
                        item.detailText = [NSString stringWithFormat:detailAvgFormat,
                                           APHLocalizedStringFromNumber([self.sleepScoring averageDataPoint])];
                    }
                    
                    item.info = NSLocalizedStringWithDefaultValue(@"APH_DASHBOARD_DAILY_SLEEP_INFO", nil, APHLocaleBundle(), @"This graph shows your answers to the daily check-in questions for sleep each day.", @"Dashboard tooltip item info text for daily check-in Sleep in Parkinson");
                    
                    APCTableViewRow *row = [APCTableViewRow new];
                    row.item = item;
                    row.itemType = rowType;
                    [rowItems addObject:row];
                }
                    break;
                    
                case kAPHDashboardItemTypeDailyCognitive:
                {
                    APHTableViewDashboardGraphItem *item = [APHTableViewDashboardGraphItem new];
                    item.caption = self.cognitiveScoring.caption;
                    item.graphData = self.cognitiveScoring;
                    item.graphType = APHDashboardGraphTypeDiscrete;
                    item.reuseIdentifier = kAPHDashboardGraphTableViewCellIdentifier;
                    item.editable = YES;
                    item.tintColor = [UIColor appTertiaryRedColor];
                    
                    item.minimumImage = [UIImage imageNamed:@"MoodSurveyClarity-5g"];
                    item.maximumImage = [UIImage imageNamed:@"MoodSurveyClarity-1g"];
                    
                    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"datasetValueKey != %@", @(NSNotFound)];
                    NSArray *moodScoringObjects = [[self.moodScoring allObjects] filteredArrayUsingPredicate:predicate];
                    
                    if ([[self.cognitiveScoring averageDataPoint] doubleValue] > 0 && moodScoringObjects.count > 1) {
                        
                        item.averageImage = [UIImage imageNamed:[NSString stringWithFormat:@"MoodSurveyClarity-%0.0fg", (double) 6 - [[self.cognitiveScoring averageDataPoint] doubleValue]]];
                        item.detailText = [NSString stringWithFormat:detailAvgFormat,
                                           APHLocalizedStringFromNumber([self.cognitiveScoring averageDataPoint])];
                    }
                    
                    
                    item.info = NSLocalizedStringWithDefaultValue(@"APH_DASHBOARD_DAILY_THINKING_INFO", nil, APHLocaleBundle(), @"This graph shows your answers to the daily check-in questions for your thinking each day.", @"Dashboard tooltip item info text for daily check-in Thinking (mental clarity) in Parkinson");
                    
                    APCTableViewRow *row = [APCTableViewRow new];
                    row.item = item;
                    row.itemType = rowType;
                    [rowItems addObject:row];
                    
                }
                    break;
                    
                case kAPHDashboardItemTypeDailyCustom:
                {
                    APHTableViewDashboardGraphItem *item = [APHTableViewDashboardGraphItem new];
                    item.caption = self.customScoring.caption;
                    item.graphData = self.customScoring;
                    item.graphType = APHDashboardGraphTypeDiscrete;
                    item.reuseIdentifier = kAPHDashboardGraphTableViewCellIdentifier;
                    item.editable = YES;
                    item.tintColor = [UIColor appTertiaryBlueColor];
                    item.minimumImage = [UIImage imageNamed:@"MoodSurveyCustom-5g"];
                    item.maximumImage = [UIImage imageNamed:@"MoodSurveyCustom-1g"];
                    
                    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"datasetValueKey != %@", @(NSNotFound)];
                    NSArray *scoringObjects = [[self.moodScoring allObjects] filteredArrayUsingPredicate:predicate];
                    
                    if ([[self.customScoring averageDataPoint] doubleValue] > 0 && scoringObjects.count > 1) {
                        item.averageImage = [UIImage imageNamed:[NSString stringWithFormat:@"MoodSurveyCustom-%0.0fg", (double) 6 - [[self.customScoring averageDataPoint] doubleValue]]];
                        item.detailText = [NSString stringWithFormat:detailAvgFormat,
                                           APHLocalizedStringFromNumber([self.customScoring averageDataPoint])];
                    }
                    
                    item.info = NSLocalizedStringWithDefaultValue(@"APH_DASHBOARD_DAILY_CUSTOM_INFO", nil, APHLocaleBundle(), @"This graph shows your answers to the custom question that you created as part of your daily check-in questions.", @"Dashboard tooltip item info text for daily check-in Custom in Parkinson");
                    
                    APCTableViewRow *row = [APCTableViewRow new];
                    row.item = item;
                    row.itemType = rowType;
                    [rowItems addObject:row];
                    
                }
                    break;
                default:
                    break;
            }
            
        }
        
        APCTableViewSection *section = [APCTableViewSection new];
        section.rows = [NSArray arrayWithArray:rowItems];
        section.sectionTitle = NSLocalizedStringWithDefaultValue(@"APH_DASHBOARD_RECENT_ACTIVITY_TITLE", nil, APHLocaleBundle(), @"Recent Activity", @"Title for the recent activity section of the dashboard table.");
        [self.items addObject:section];
    }
    
    [self.tableView reloadData];
}


#pragma mark - APCDashboardTableViewCellDelegate

- (void)dashboardTableViewCellDidTapLegendTitle:(APCDashboardTableViewCell *)__unused cell
{
    APCCorrelationsSelectorViewController *correlationSelector = [[APCCorrelationsSelectorViewController alloc]initWithScoringObjects:@[self.tapRightScoring, self.tapLeftScoring, self.gaitScoring, self.stepScoring, self.phonationScoring]];
    correlationSelector.delegate = self;
    [self.navigationController pushViewController:correlationSelector animated:YES];
}

- (void)dashboardTableViewCellDidTapExpand:(APCDashboardTableViewCell *)cell
{
    if ([cell isKindOfClass:[APHDashboardGraphTableViewCell class]]) {
        NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
        
        APHTableViewDashboardGraphItem *graphItem = (APHTableViewDashboardGraphItem *)[self itemForIndexPath:indexPath];
        
        CGRect initialFrame = [cell convertRect:cell.bounds toView:self.view.window];
        self.presentAnimator.initialFrame = initialFrame;
        
        APCGraphViewController *graphViewController = [[UIStoryboard storyboardWithName:@"APCDashboard" bundle:[NSBundle appleCoreBundle]] instantiateViewControllerWithIdentifier:@"APCLineGraphViewController"];
        
        graphViewController.graphItem = graphItem;
        graphItem.graphData.scoringDelegate = graphViewController;
        [self.navigationController presentViewController:graphViewController animated:YES completion:nil];
    }
}

#pragma mark - CorrelationsSelector Delegate

- (void)viewController:(APCCorrelationsSelectorViewController *)__unused viewController didChangeCorrelatedScoringDataSource:(APHScoring *)scoring
{
    self.correlatedScoring = scoring;
    [self prepareData];
}

#pragma mark - UITableViewDataSource

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    APCTableViewItem *dashboardItem = [self itemForIndexPath:indexPath];
    UITableViewCell *cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];
    
    if ([dashboardItem isKindOfClass:[APHTableViewDashboardGraphItem class]]) {
        
        APHTableViewDashboardGraphItem *graphItem = (APHTableViewDashboardGraphItem *)dashboardItem;
        APHDashboardGraphTableViewCell *graphCell = (APHDashboardGraphTableViewCell *)cell;

        graphCell.showMedicationLegend = graphItem.showMedicationLegend;
        graphCell.discreteGraphView.usesLegend = graphItem.showMedicationLegend;
        [graphCell.legendButton setAttributedTitle:graphItem.legend forState:UIControlStateNormal];
        graphCell.subTitleLabel.hidden = NO;
        
        // Setup the legend
        if (graphItem.showMedicationLegend) {
            [graphCell.tintViews enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                [self setupPlotPoint:obj legendIndex:idx tintColor:graphItem.tintColor];
            }];
        }
    }

	((APCDashboardTableViewCell *)cell).titleLabel.textColor = [UIColor blackColor];
    
    return cell;
}

- (void)setupPlotPoint:(APCCircleView *)shape legendIndex:(NSUInteger)legendIndex tintColor:(UIColor *)tintColor
{
    if ((legendIndex == APHMedicationTimingChoiceBefore) || [self medicationTrackingHidden]) { 
        shape.tintColor = tintColor;
    }
    else if (legendIndex == APHMedicationTimingChoiceAfter) {
        shape.solidDot = YES;
        shape.tintColor = tintColor;
    }
    else {
        shape.tintColor = [UIColor appTertiaryGrayColor];
    }
}


#pragma mark - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    APCTableViewItem *dashboardItem = [self itemForIndexPath:indexPath];
    
    if ([dashboardItem isKindOfClass:[APHTableViewDashboardGraphItem class]]) {
        APHTableViewDashboardGraphItem *graphItem = (APHTableViewDashboardGraphItem *)dashboardItem;
        CGFloat rowHeight = [super tableView:tableView heightForRowAtIndexPath:indexPath];
        
        if (graphItem.showMedicationLegend) {
            rowHeight += [APHDashboardGraphTableViewCell medicationLegendContainerHeight];
        }
        
        return rowHeight;
    }
    
    return [super tableView:tableView heightForRowAtIndexPath:indexPath];
}

#pragma mark - ORKTaskViewControllerDelegate

- (void)taskViewController:(ORKTaskViewController *)taskViewController didFinishWithReason:(ORKTaskViewControllerFinishReason)reason error:(nullable NSError *)error
{
    if (![[taskViewController.task identifier] isEqualToString:kAPHMonthlyReportTaskIdentifier]) {
        [self prepareData];
    }
    
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)dismissPresentedViewController {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (nullable ORKStepViewController *)taskViewController:(ORKTaskViewController *)taskViewController viewControllerForStep:(ORKStep *)step {
    if ([[taskViewController.task identifier] isEqualToString:kAPHMonthlyReportTaskIdentifier] &&
        [step.identifier isEqualToString:kAPHMonthlyReportHTMLStepIdentifier]) {
        
        // TODO: syoung 03/01/2016 Remove hardcoding and clean up architecture
        NSString *displayURLString = @"http://parkinsonmpower.org/report/index.html";
        NSString *pdfURLSuffix = @"#pdf";
        BOOL isStaging = ([[APHAppDelegate sharedAppDelegate] environment] == SBBEnvironmentStaging);
        NSString *sessionToken = isStaging ? @"aaa" : [[[[APHAppDelegate sharedAppDelegate] dataSubstrate] currentUser] sessionToken];
        NSString *javascriptCall = [NSString stringWithFormat:@"window.display(\"%@\")", sessionToken];
        
        // Set the allowed orientation mask to allow landscape
        [[APHAppDelegate sharedAppDelegate] setPreferredOrientationMask:UIInterfaceOrientationMaskAllButUpsideDown];
        
        APHWebViewStepViewController *vc = [APHWebViewStepViewController instantiateWithURLString:displayURLString pdfURLSuffix:pdfURLSuffix javascriptCall:javascriptCall];
        vc.step = step;

        return vc;
    }
    return nil;
}


#pragma mark - monthly report

- (IBAction)monthlyReportTapped:(id)sender {
    SBAConsentDocumentFactory *factory = [[SBAConsentDocumentFactory alloc] initWithJsonNamed:@"MonthlyReport"];
    SBANavigableOrderedTask *task = [[SBANavigableOrderedTask alloc] initWithIdentifier:kAPHMonthlyReportTaskIdentifier
                                                                                  steps:factory.steps];
    ORKTaskViewController *vc = [[ORKTaskViewController alloc] initWithTask:task restorationData:nil delegate:self];
    [self presentViewController:vc animated:YES completion:nil];
}



@end

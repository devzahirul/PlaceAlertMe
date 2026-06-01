#include <gtest/gtest.h>
#include "history_engine.h"
#include <cstdio>
#include <cstdlib>
#include <string>
#include <unistd.h>

using namespace geo_engine;

class NavigationHistoryEngineTest : public ::testing::Test {
protected:
    NavigationHistoryEngine history;
    std::string directory;

    void SetUp() override {
        char templ[] = "/tmp/navigation_history_test_XXXXXX";
        char* result = mkdtemp(templ);
        ASSERT_NE(result, nullptr);
        directory = result;
    }

    void TearDown() override {
        std::remove((directory + "/2026-05-19.jsonl").c_str());
        std::remove((directory + "/2026-05-20.jsonl").c_str());
        std::remove((directory + "/2026-05-21.jsonl").c_str());
        rmdir(directory.c_str());
    }
};

TEST_F(NavigationHistoryEngineTest, RoutePointFilterKeepsUsefulPath) {
    EXPECT_TRUE(history.appendRoutePoint(
        directory,
        "2026-05-21",
        HistoryRoutePoint(1000, 23.7800, 90.4100, 0.0)
    ));

    EXPECT_FALSE(history.appendRoutePoint(
        directory,
        "2026-05-21",
        HistoryRoutePoint(11000, 23.78001, 90.41001, 0.0)
    ));

    EXPECT_TRUE(history.appendRoutePoint(
        directory,
        "2026-05-21",
        HistoryRoutePoint(70000, 23.78001, 90.41001, 0.0)
    ));

    HistoryDay day;
    ASSERT_TRUE(history.loadDay(directory, "2026-05-21", day));
    EXPECT_EQ(day.points.size(), 2);
    EXPECT_EQ(day.summary.pointCount, 2);
}

TEST_F(NavigationHistoryEngineTest, AlertEventsArePersistedInDay) {
    HistoryAlertEvent event;
    event.id = "event-1";
    event.alertId = "alert-1";
    event.task = "Buy groceries";
    event.place = "Market";
    event.address = "Dhaka";
    event.eventType = "Arriving";
    event.timestampMs = 2000;
    event.latitude = 23.7800;
    event.longitude = 90.4100;

    EXPECT_TRUE(history.appendAlertEvent(directory, "2026-05-21", event));

    HistoryDay day;
    ASSERT_TRUE(history.loadDay(directory, "2026-05-21", day));
    ASSERT_EQ(day.alertEvents.size(), 1);
    EXPECT_EQ(day.alertEvents[0].task, "Buy groceries");
    EXPECT_EQ(day.summary.alertEventCount, 1);
}

TEST_F(NavigationHistoryEngineTest, ActivityEventsArePersistedInDay) {
    EXPECT_TRUE(history.appendActivityEvent(
        directory,
        "2026-05-21",
        HistoryActivityEvent(3000, "walking", "high")
    ));
    EXPECT_TRUE(history.appendActivityEvent(
        directory,
        "2026-05-21",
        HistoryActivityEvent(1000, "stationary", "medium")
    ));

    HistoryDay day;
    ASSERT_TRUE(history.loadDay(directory, "2026-05-21", day));
    ASSERT_EQ(day.activityEvents.size(), 2);
    EXPECT_EQ(day.activityEvents[0].activityType, "stationary");
    EXPECT_EQ(day.activityEvents[1].activityType, "walking");
    EXPECT_NE(
        history.loadDayJson(directory, "2026-05-21").find("\"activityEvents\""),
        std::string::npos
    );
}

TEST_F(NavigationHistoryEngineTest, ListsSummariesAndPrunesOldDays) {
    EXPECT_TRUE(history.appendRoutePoint(
        directory,
        "2026-05-19",
        HistoryRoutePoint(1000, 23.7800, 90.4100, 0.0)
    ));
    EXPECT_TRUE(history.appendRoutePoint(
        directory,
        "2026-05-21",
        HistoryRoutePoint(2000, 23.7900, 90.4200, 0.0)
    ));

    auto summaries = history.listDaySummaries(directory);
    ASSERT_EQ(summaries.size(), 2);
    EXPECT_EQ(summaries[0].dayKey, "2026-05-21");
    EXPECT_EQ(summaries[1].dayKey, "2026-05-19");

    EXPECT_EQ(history.pruneBeforeDay(directory, "2026-05-20"), 1);
    summaries = history.listDaySummaries(directory);
    ASSERT_EQ(summaries.size(), 1);
    EXPECT_EQ(summaries[0].dayKey, "2026-05-21");
}

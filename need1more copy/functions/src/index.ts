// import * as functions from "firebase-functions";
import * as functionsV1 from "firebase-functions/v1";
import * as admin from "firebase-admin";

admin.initializeApp();

interface EventData {
  eventName: string;
  peopleCount: number;
  eventTime: number;
  id: string;
  notified?: boolean;
}
export const cleanUpEvents = functionsV1.pubsub
  .schedule("every 5 minutes")
  .onRun(async (context) => {
    const now = Date.now();
    const ref = admin.database().ref("events");

    const snapshot = await ref.once("value");
    const events = snapshot.val() as { [key: string]: EventData } | null;

    if (events) {
      const updates: { [key: string]: null } = {};
      const notifications: { key: string; event: EventData }[] = [];

      Object.keys(events).forEach((key) => {
        const event = events[key];

        if (event.eventTime) {
          const timeLeft = event.eventTime - now;

          // Delete expired events
          if (timeLeft <= 0) {
            updates[key] = null;
          }

          // Send notification if 10 minutes before the event
          else if (timeLeft <= 10 * 60 * 1000 && !event.notified) {
            notifications.push({ key, event });
          }
        }
      });

      // Delete expired events
      if (Object.keys(updates).length > 0) {
        await ref.update(updates);
        console.log(`Deleted ${Object.keys(updates).length} expired events`);
      }

      // Send notifications
      for (const { key, event } of notifications) {
        await sendNotification(event.eventName, event.peopleCount);
        // Mark event as notified
        await ref.child(key).update({ notified: true });
      }
    }

    return null;
  });

// Helper to send push notification
async function sendNotification(eventName: string, peopleCount: number): Promise<void> {
  const message: admin.messaging.Message = {
    notification: {
      title: `Upcoming Event: ${eventName}`,
      body: `${peopleCount} people needed. Starting soon!`,
    },
    topic: "events", // All devices subscribed to 'events' topic
  };

  await admin.messaging().send(message);
}

import { onSchedule } from "firebase-functions/v2/scheduler";
import * as admin from "firebase-admin";

admin.initializeApp();

interface EventData {
  eventName: string;
  peopleCount: number;
  eventTime: number;
  id: string;
  notified?: boolean;
}

// Cloud Function: runs every minute
export const cleanUpEvents = onSchedule("every 1 minutes", async (event) => {
  const now = Date.now();
  const ref = admin.database().ref("events");

  const snapshot = await ref.once("value");
  const events = snapshot.val() as { [key: string]: EventData } | null;

  if (!events) {
    console.log('No events found.');
    return;
  }

  const deletePromises: Promise<void>[] = [];

  Object.entries(events).forEach(([key, eventData]) => {
    if (eventData.eventTime && eventData.eventTime <= now) {
      console.log(`Deleting expired event: ${eventData.eventName}`);
      deletePromises.push(ref.child(key).remove());
    }
  });

  if (deletePromises.length > 0) {
    await Promise.all(deletePromises);
    console.log(`Deleted ${deletePromises.length} expired events`);
  } else {
    console.log('No expired events to delete.');
  }
});

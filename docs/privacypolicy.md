# SmartBud Privacy Policy

**Effective date:** 2026-07-23

SmartBud is a personal finance tracker for iPhone. This policy explains what data the app handles, how it is stored, and what we — the SmartBud project — do (and do not) do with it.

## 1. Summary

- The app does not require an account. We do not collect your name, email, or any other contact information.
- Your transactions, categories, and budgets are stored on your device. If you turn on iCloud sync, the same data is also stored in your **private** iCloud database via Apple CloudKit. We do not operate any server that holds your data.
- The app contains no advertising, no third-party analytics, and no crash-reporting SDK. We have no way to see how you use the app.

## 2. Data stored on your device

The app writes the following data to a local SwiftData store on your iPhone:

- **Transactions** you record: amount, date, category, note, optional photo
- **Categories** you create or customise
- **Budgets** you set
- **App preferences** (currency, theme, language, notification schedules, app-lock on/off)

This data stays on your device until you delete the app or use **Settings → Erase Data**.

## 3. iCloud sync (optional)

If you sign in to iCloud and have iCloud Drive enabled for SmartBud, the data listed in section 2 is synced to your **private CloudKit database** under the container identifier `iCloud.com.iorest.smartbud`. The sync is end-to-end: SmartBud and the SmartBud project never see, transmit to, or store your data on any server we control. Apple acts as the data processor under their [iCloud Terms and Privacy Policy](https://www.apple.com/legal/internet-services/icloud/).

You can disable iCloud sync at any time from **iOS Settings → [your name] → iCloud → Show All → SmartBud**. Disabling sync stops new data from being uploaded; data already on other devices remains on those devices until you delete it there too.

## 4. Apple services we use

SmartBud uses the following Apple-provided services, which are governed by Apple's terms:

| Service | Purpose | What it touches |
|---------|---------|-----------------|
| **CloudKit** | Sync your data across your devices | The data in section 2, stored in your private iCloud database |
| **StoreKit** (In-App Purchase) | Process SmartBud Pro subscriptions and the lifetime unlock | Apple ID, purchase receipts. **We never see your payment details.** |
| **UserNotifications** | Send the local reminders you configure | Nothing leaves your device |
| **LocalAuthentication** | Unlock the app with Face ID / Touch ID | Biometric data never leaves the Secure Enclave on your device |

We do not embed any third-party analytics, advertising, or crash-reporting SDK. We do not use cookies, web beacons, tracking pixels, or fingerprinting.

## 5. Permissions the app requests

The app asks for the following iOS permissions. Each is optional and the app works without it:

- **Face ID / Touch ID** (`NSFaceIDUsageDescription`) — to unlock the app. Required only if you turn on App Lock in Settings.
- **Add to Photo Library** (`NSPhotoLibraryAddUsageDescription`) — to save a screenshot of a transaction when you tap the share button. The app does not read your existing photos.

If you decline either permission, the corresponding feature is disabled and the rest of the app continues to work normally.

## 6. Pro subscriptions and the lifetime unlock

SmartBud Pro is offered via Apple's In-App Purchase system. When you buy a subscription or the lifetime unlock:

- Apple processes the payment. We never see your credit card, Apple Pay credentials, or billing address.
- We receive a non-personal receipt token from Apple that confirms the purchase. This token lets the app unlock Pro features on your device.
- We do not store your name or email. The receipt is verified locally on your device against Apple's servers.

Subscriptions and the lifetime unlock are tied to your Apple ID. You can manage or cancel them from **iOS Settings → [your name] → Subscriptions**.

## 7. Data export and deletion

You can export a copy of all your data as a JSON file from **Settings → Export My Data**, and you can erase all your data (local + iCloud) from **Settings → Erase Data**. The erase operation removes the local store and the CloudKit record zone associated with the app. After erasure, the data is gone and cannot be recovered by us, by Apple (beyond standard iCloud retention windows), or by you.

## 8. Children's privacy

SmartBud is not directed at children under 13. We do not knowingly collect personal information from children under 13. Because the app collects no personal information from anyone (see section 1), this restriction is largely a formality, but if you believe a child under 13 has used the app, contact us at the address below and we will assist you in deleting any data the app may have stored locally on that device.

The app does not ask for an age, and it does not block usage by age. Parents and guardians who want to restrict the app on a child's device can use iOS's built-in Screen Time controls.

## 9. International data transfers

Your data, if iCloud sync is on, is stored in the iCloud region associated with your Apple ID. Apple may process the data in other regions as part of normal iCloud operation; see Apple's [iCloud data privacy page](https://support.apple.com/en-us/108756) for details. SmartBud itself does not transfer your data across borders.

## 10. Changes to this policy

We may update this policy from time to time. The "Effective date" at the top shows when it was last revised. Material changes will be announced in the app's release notes for the next update. Continued use of the app after a change takes effect means you accept the updated policy.

## 11. Contact

Questions, requests, or complaints about this policy: **iorest@qq.com**.

We aim to respond within 30 days.

---

This document is provided for informational purposes and does not constitute legal advice. If you have specific legal questions, please consult a qualified attorney in your jurisdiction.

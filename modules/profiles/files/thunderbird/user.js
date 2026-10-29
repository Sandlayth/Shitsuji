// Managed by Shitsuji (profiles::thunderbird) -- edits here are overwritten.
// New-mail desktop notifications, routed to dunst via libnotify. On Linux the
// Thunderbird biff alert IS a libnotify notification, so dunst renders it with
// the sender and subject. user.js is reapplied at every Thunderbird startup.
user_pref("mail.biff.show_alert", true);
user_pref("mail.biff.alert.show_sender", true);
user_pref("mail.biff.alert.show_subject", true);
user_pref("mail.biff.alert.show_preview", true);

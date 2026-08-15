pragma Singleton
import Quickshell
import Quickshell.Services.Notifications

Singleton {
    id: root

    property list<Notification> notifications: []
    property var toastQueue: []
    property var unreadIds: ({})
    property int unreadCount: 0
    property bool centerVisible: false
    property int maxVisibleToasts: 5

    function notificationKey(notif) {
        return notif ? String(notif.id) : ""
    }

    function normalizeMediaSource(source) {
        var value = source === undefined || source === null ? "" : String(source)
        if (value === "")
            return ""

        if (value.indexOf("file://") === 0
                || value.indexOf("qrc:/") === 0
                || value.indexOf("image://") === 0
                || value.indexOf("http://") === 0
                || value.indexOf("https://") === 0) {
            return value
        }

        if (value.charAt(0) === "/")
            return "file://" + value

        return Quickshell.iconPath(value, "")
    }

    function notificationMediaSource(notif) {
        if (!notif)
            return ""

        var imageSource = normalizeMediaSource(notif.image)
        if (imageSource !== "")
            return imageSource

        if (notif.hints) {
            var hintedSource = normalizeMediaSource(notif.hints["image-path"] || notif.hints["image_path"])
            if (hintedSource !== "")
                return hintedSource
        }

        return normalizeMediaSource(notif.appIcon)
    }

    function syncUnreadCount() {
        unreadCount = Object.keys(unreadIds).length
    }

    function markUnread(notif) {
        var key = notificationKey(notif)
        if (key === "" || unreadIds[key])
            return

        var nextUnreadIds = {}
        for (var unreadKey in unreadIds)
            nextUnreadIds[unreadKey] = unreadIds[unreadKey]

        nextUnreadIds[key] = true
        unreadIds = nextUnreadIds
        syncUnreadCount()
    }

    function clearUnread(notif) {
        var key = notificationKey(notif)
        if (key === "" || !unreadIds[key])
            return

        var nextUnreadIds = {}
        for (var unreadKey in unreadIds) {
            if (unreadKey !== key)
                nextUnreadIds[unreadKey] = unreadIds[unreadKey]
        }

        unreadIds = nextUnreadIds
        syncUnreadCount()
    }

    function clearUnreadAll() {
        unreadIds = ({})
        unreadCount = 0
    }

    function removeNotificationInstance(notif, preserveUnread) {
        var wasTracked = notifications.indexOf(notif) !== -1 || toastQueue.indexOf(notif) !== -1

        notifications = notifications.filter(n => n !== notif)
        toastQueue = toastQueue.filter(n => n !== notif)

        if (wasTracked && !preserveUnread)
            clearUnread(notif)
    }

    function removeNotificationsById(id, preserveUnread) {
        var key = String(id)
        var removedUnread = unreadIds[key] === true

        notifications = notifications.filter(n => String(n.id) !== key)
        toastQueue = toastQueue.filter(n => String(n.id) !== key)

        if (!preserveUnread && removedUnread) {
            var nextUnreadIds = {}
            for (var unreadKey in unreadIds) {
                if (unreadKey !== key)
                    nextUnreadIds[unreadKey] = unreadIds[unreadKey]
            }

            unreadIds = nextUnreadIds
            syncUnreadCount()
        }

        return removedUnread
    }

    function trackNotification(notif) {
        notif.closed.connect(function() {
            root.removeNotificationInstance(notif, false)
        })
    }

    function clearAll() {
        let snapshot = [...notifications]
        notifications = []
        toastQueue = []
        clearUnreadAll()

        for (var n of snapshot)
            n.dismiss()
    }

    function toggleCenter() {
        centerVisible = !centerVisible
        if (centerVisible)
            clearUnreadAll()
    }

    NotificationServer {
        keepOnReload: false

        onNotification: (notif) => {
            notif.tracked = true
            let wasUnread = root.removeNotificationsById(notif.id, true)
            root.trackNotification(notif)

            root.notifications = [...root.notifications, notif]
            root.toastQueue = [...root.toastQueue.slice(-(root.maxVisibleToasts - 1)), notif]

            if (wasUnread || !root.centerVisible)
                root.markUnread(notif)
        }
    }

    function dismissToast(notif) {
        toastQueue = toastQueue.filter(n => n !== notif)
    }

    function dismiss(notif) {
        removeNotificationInstance(notif, false)
        notif.dismiss()
    }
}

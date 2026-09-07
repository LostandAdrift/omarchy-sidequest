import QtQuick
import Quickshell
import "runtime" as Local

ShellRoot {
    id: test
    property int step: 0
    Component.onCompleted: Local.Library.request({
        action: "scan"
    })
    Connections {
        target: Local.Library
        function onFinished(request, response) {
            if (Local.Library.busy || Local.Library.running) {
                console.error("FAILURE_TEST_OVERLAP");
                Qt.exit(1);
                return;
            }
            if (test.step === 0) {
                if (response.ok || !Local.Library.error) {
                    console.error("FAILURE_NOT_REPORTED");
                    Qt.exit(2);
                    return;
                }
                test.step = 1;
                Qt.callLater(function () {
                    Local.Library.request({
                        action: "scan"
                    });
                });
            } else {
                if (!response.ok || Local.Library.error || !Local.Library.ready) {
                    console.error("RECOVERY_FAILED");
                    Qt.exit(3);
                    return;
                }
                console.log("FAILURE_RECOVERY_PASS", Quickshell.env("SIDEQUEST_FIXTURE_FAILURE"));
                Qt.quit();
            }
        }
    }
    Timer {
        interval: 17000
        running: true
        onTriggered: Qt.exit(4)
    }
}

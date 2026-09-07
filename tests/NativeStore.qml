import QtQuick
import Quickshell
import "runtime" as Local

ShellRoot {
    property int step:0
    Component.onCompleted:{
        if(!Local.Library.request({action:"scan"}))Qt.exit(1);
        if(Local.Library.request({action:"scan"}))Qt.exit(2);
    }
    Connections {
        target:Local.Library
        function onFinished(request,response){
            if(!response.ok || !Local.Library.ready || Local.Library.busy || Local.Library.running){console.error("STORE_FAIL",Local.Library.status);Qt.exit(3);return;}
            step++;
            if(step===1){Qt.callLater(function(){Local.Library.request({action:"scan"});});}
            else {
                console.log("STORE_PASS",JSON.stringify({requests:Local.Library.requests,ready:Local.Library.ready,running:Local.Library.running}));Qt.quit();
            }
        }
    }
    Timer {interval:15000;running:true;onTriggered:{console.error("STORE_TIMEOUT");Qt.exit(4);}}
}

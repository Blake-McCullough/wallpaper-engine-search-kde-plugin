import QtQuick 2.0
// test stand-in: answers commands via the Python harness's `answer(cmd)` slot
Item {
    property string engine
    property var connectedSources: []
    signal newData(string sourceName, var data)
    function connectSource(cmd) { var out = harness.answer(cmd); Qt.callLater(function(){ newData(cmd, {stdout: out, stderr: ""}); }); }
    function disconnectSource(cmd) {}
}

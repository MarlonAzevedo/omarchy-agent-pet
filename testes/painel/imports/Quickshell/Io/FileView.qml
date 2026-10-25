import QtQuick
QtObject { property string path; property bool watchChanges; property bool atomicWrites; property bool printErrors; signal fileChanged(); signal loaded(); signal loadFailed(); function reload() {} function text() { return "" } function setText(t) { console.log("WRITE", t) } }

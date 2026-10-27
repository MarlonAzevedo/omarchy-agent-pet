import QtQuick
QtObject { property var command; property bool running; property var stdout; signal exited(int exitCode, int exitStatus) }

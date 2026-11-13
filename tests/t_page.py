"""Offscreen test: loads WorkshopPage.qml against a stubbed Plasma DataSource and the real helper's JSON shapes."""
import base64, json, os, sys
os.environ["QT_QPA_PLATFORM"] = "offscreen"
from pathlib import Path
from PyQt6.QtCore import QObject, QUrl, pyqtSlot, QTimer
from PyQt6.QtGui import QGuiApplication
from PyQt6.QtQml import QQmlApplicationEngine

root = Path(__file__).resolve().parent.parent
log = []
state = {"pending_done": False}
ITEMS = [{"id": "111", "title": "Neon City", "author": "A", "subs": 12345, "thumb": "", "installed": False, "source": ""},
         {"id": "222", "title": "Forest", "author": "B", "subs": 5, "thumb": "", "installed": True, "source": "/x/222/f.mp4+video"}]

class Harness(QObject):
    @pyqtSlot(str, result=str)
    def answer(self, cmd):
        log.append(cmd)
        parts = cmd.split("; \"$W\" ")[1].rsplit(" #", 1)[0]
        name, _, arg = parts.partition(" ")
        if name == "search":
            import shlex; q = json.loads(shlex.split(arg)[0])
            log.append(("query", q))
            return json.dumps({"items": ITEMS, "total": 61, "error": "", "per_page": 30})
        if name == "status":
            return json.dumps({"logged_in": True})
        if name == "subscribe":
            return json.dumps({"ok": True, "error": ""})
        if name == "installed":
            return json.dumps({"installed": {"111": "/x/111/a.mp4+video"} if state["pending_done"] else {}})
        return "{}"

app = QGuiApplication(sys.argv)
eng = QQmlApplicationEngine()
eng.addImportPath(str(root / "tests" / "stub"))
h = Harness()
eng.rootContext().setContextProperty("harness", h)
wrap = root / "tests" / "wrap.qml"
wrap.write_text('import QtQuick 2.6\nimport QtQuick.Window 2.2\nimport "../plugin/contents/ui/page"\n'
                'Window { visible: true; width: 900; height: 600\n WorkshopPage { id: p; anchors.fill: parent; objectName: "p"; libraryPath: "/lib" } }\n')
eng.load(QUrl.fromLocalFile(str(wrap)))
assert eng.rootObjects(), "QML failed to load"
page = eng.rootObjects()[0].findChild(QObject, "p")
res = {}

def step1():
    res["count"] = page.property("total")
    page.setProperty("tagState", {"Everyone": 1, "Anime": 2})
    page.metaObject()  # noqa
    from PyQt6.QtCore import QMetaObject, Qt, Q_ARG
    QMetaObject.invokeMethod(page, "search", Qt.ConnectionType.DirectConnection, Q_ARG("QVariant", True))
    QTimer.singleShot(150, step2)

def step2():
    from PyQt6.QtCore import QMetaObject, Qt, Q_ARG
    QMetaObject.invokeMethod(page, "subscribe", Qt.ConnectionType.DirectConnection, Q_ARG("QVariant", "111"))
    QTimer.singleShot(150, step3)

def step3():
    res["pending"] = page.property("pendingCount")
    state["pending_done"] = True
    from PyQt6.QtCore import QMetaObject, Qt
    QMetaObject.invokeMethod(page, "checkPending", Qt.ConnectionType.DirectConnection)
    QTimer.singleShot(150, finish)

def finish():
    res["pending_after"] = page.property("pendingCount")
    q = [x[1] for x in log if isinstance(x, tuple)][-1]
    ok = (res["count"] == 61 and q["include"] == ["Everyone"] and q["exclude"] == ["Anime"] and q["library"] == "/lib"
          and res["pending"] == 1 and res["pending_after"] == 0)
    print("results:", res, "last query:", q)
    print("PASS" if ok else "FAIL")
    wrap.unlink()
    app.exit(0 if ok else 1)

QTimer.singleShot(300, step1)
sys.exit(app.exec())

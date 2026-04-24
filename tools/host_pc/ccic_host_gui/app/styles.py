APP_QSS = """
QWidget {
    background-color: #08101c;
    color: #e6edf8;
    font-family: "Segoe UI", "Microsoft YaHei UI";
    font-size: 13px;
}

QMainWindow {
    background: #08101c;
}

QFrame#TopBanner {
    background: qlineargradient(
        x1:0, y1:0, x2:1, y2:1,
        stop:0 #0c1f39, stop:0.55 #12315a, stop:1 #1a4876
    );
    border: 1px solid #2f6cb0;
    border-radius: 14px;
}

QFrame#StatusCard {
    background: qlineargradient(
        x1:0, y1:0, x2:0, y2:1,
        stop:0 #0f2440, stop:1 #0a1a2f
    );
    border: 1px solid #285588;
    border-radius: 10px;
}

QLabel#TitleLabel {
    font-size: 24px;
    font-weight: 800;
    color: #f2f8ff;
}

QLabel#SubTitleLabel {
    color: #b6d8ff;
    font-size: 13px;
}

QLabel#ContestLabel {
    color: #ffd782;
    font-size: 12px;
    font-weight: 700;
}

QLabel#ClockLabel {
    color: #c6dcff;
    font-size: 12px;
}

QLabel#CardTitle {
    color: #9bc9ff;
    font-size: 11px;
    font-weight: 600;
}

QLabel#CardValue {
    color: #f4fbff;
    font-size: 15px;
    font-weight: 700;
}

QGroupBox {
    border: 1px solid #23466f;
    border-radius: 10px;
    margin-top: 10px;
    padding-top: 10px;
    background-color: #0d182b;
}

QGroupBox::title {
    subcontrol-origin: margin;
    left: 10px;
    padding: 0 6px 0 6px;
    color: #8fd0ff;
    font-weight: 700;
}

QLineEdit, QTextEdit, QPlainTextEdit, QComboBox, QSpinBox, QDoubleSpinBox {
    background-color: #091325;
    border: 1px solid #2c4f78;
    border-radius: 8px;
    padding: 6px 8px;
    selection-background-color: #1f8fff;
}

QLineEdit:focus, QTextEdit:focus, QPlainTextEdit:focus, QComboBox:focus, QSpinBox:focus, QDoubleSpinBox:focus {
    border: 1px solid #59b8ff;
}

QTabWidget::pane {
    border: 1px solid #25486f;
    border-radius: 10px;
    background-color: #0d182b;
    top: -1px;
}

QTabBar::tab {
    background: #10243f;
    border: 1px solid #2e5787;
    color: #c5deff;
    border-top-left-radius: 8px;
    border-top-right-radius: 8px;
    padding: 8px 14px;
    margin-right: 2px;
}

QTabBar::tab:selected {
    background: #1a4371;
    color: #f4fbff;
    border-bottom-color: #1a4371;
}

QPushButton {
    border: 1px solid #3f71a9;
    border-radius: 9px;
    padding: 7px 12px;
    background: qlineargradient(
        x1:0, y1:0, x2:0, y2:1,
        stop:0 #1d4d84, stop:1 #12365e
    );
    color: #f0f7ff;
    font-weight: 700;
}

QPushButton:hover {
    border-color: #76c3ff;
    background: qlineargradient(
        x1:0, y1:0, x2:0, y2:1,
        stop:0 #2364aa, stop:1 #184979
    );
}

QPushButton:pressed {
    background: #153a63;
}

QPushButton#DangerButton {
    border: 1px solid #a95b67;
    background: qlineargradient(
        x1:0, y1:0, x2:0, y2:1,
        stop:0 #873847, stop:1 #682b37
    );
}

QPushButton#AccentButton {
    border: 1px solid #3ea8a0;
    background: qlineargradient(
        x1:0, y1:0, x2:0, y2:1,
        stop:0 #16847c, stop:1 #0f625c
    );
}

QLabel#BadgeOffline {
    background-color: #3e222b;
    color: #ffb2be;
    border: 1px solid #8e4d5c;
    border-radius: 10px;
    padding: 2px 8px;
    font-weight: 700;
}

QLabel#BadgeOnline {
    background-color: #123627;
    color: #8df5be;
    border: 1px solid #2f8a5f;
    border-radius: 10px;
    padding: 2px 8px;
    font-weight: 700;
}
"""

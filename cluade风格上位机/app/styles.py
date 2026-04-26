APP_QSS = """
QWidget {
    background-color: #f6f1e8;
    color: #2f2925;
    font-family: "Segoe UI", "Microsoft YaHei UI";
    font-size: 13px;
}

QLabel,
QFrame[card="banner"] QWidget,
QFrame[card="status"] QWidget,
QFrame[card="module"] QWidget,
QFrame[card="reserved"] QWidget {
    background-color: transparent;
}

QMainWindow {
    background-color: #f6f1e8;
}

QWidget#CentralRoot {
    background-color: #f6f1e8;
}

QFrame[card="banner"] {
    background-color: #f4ede4;
    border: 1px solid #ddd3c7;
    border-radius: 8px;
}

QFrame[card="status"] {
    background-color: #fbf7f2;
    border: 1px solid #ded4c8;
    border-radius: 8px;
}

QFrame[card="module"] {
    background-color: #fbf7f2;
    border: 1px solid #ded4c8;
    border-radius: 8px;
}

QFrame[card="reserved"] {
    background-color: #fffaf5;
    border: 1px solid #e1d6ca;
    border-radius: 8px;
}

QFrame[card="module"][hovered="true"] {
    border-color: #cbb9a8;
    background-color: #fffaf5;
}

QFrame[card="reserved"][hovered="true"] {
    border-color: #cbb9a8;
    background-color: #fffdf9;
}

QFrame[card="module"][active="true"] {
    border-color: #c96f4b;
    background-color: #f8efe5;
}

QFrame[card="reserved"][active="true"] {
    border-color: #c96f4b;
    background-color: #f8efe5;
}

QFrame[card="status"][hovered="true"] {
    border-color: #ccb9a8;
    background-color: #fffaf5;
}

QFrame#SectionHeader {
    background-color: transparent;
    border: none;
}

QLabel[textRole="title"] {
    font-size: 24px;
    font-weight: 700;
    color: #26211d;
}

QLabel[textRole="subtitle"] {
    color: #6e6257;
    font-size: 13px;
}

QLabel[textRole="bannerNote"] {
    color: #85786d;
    font-size: 12px;
}

QLabel[textRole="sectionTitle"] {
    color: #2a2521;
    font-size: 15px;
    font-weight: 600;
}

QLabel[textRole="sectionSubtitle"] {
    color: #776b60;
    font-size: 12px;
}

QLabel[textRole="statusTitle"] {
    color: #7a6d61;
    font-size: 11px;
    font-weight: 600;
}

QLabel[textRole="statusValue"] {
    color: #2a2521;
    font-size: 16px;
    font-weight: 700;
}

QLabel[textRole="helper"] {
    color: #7a6d61;
    font-size: 12px;
}

QLabel[textRole="monoHint"] {
    color: #5f554d;
    font-size: 12px;
    font-family: "Consolas", "Microsoft YaHei UI";
}

QLabel[badge="online"],
QLabel[badge="offline"],
QLabel[chip="neutral"],
QLabel[chip="accent"],
QLabel[chip="positive"],
QLabel[chip="warning"] {
    border-radius: 10px;
    padding: 2px 10px;
    font-size: 11px;
    font-weight: 700;
}

QLabel[badge="online"] {
    background-color: #eef3ea;
    color: #56684b;
    border: 1px solid #cfdac8;
}

QLabel[badge="offline"] {
    background-color: #f6ebe7;
    color: #9a5d49;
    border: 1px solid #e2c8bb;
}

QLabel[chip="neutral"] {
    background-color: #efe8de;
    color: #6d6258;
    border: 1px solid #ddd2c5;
}

QLabel[chip="accent"] {
    background-color: #f4e3d8;
    color: #9a5538;
    border: 1px solid #ddb49f;
}

QLabel[chip="positive"] {
    background-color: #efece3;
    color: #657052;
    border: 1px solid #d8d2c1;
}

QLabel[chip="warning"] {
    background-color: #f7ecd9;
    color: #956c35;
    border: 1px solid #e8d0a3;
}

QLineEdit,
QTextEdit,
QPlainTextEdit,
QComboBox,
QSpinBox,
QDoubleSpinBox {
    background-color: #fffdf9;
    border: 1px solid #d9cec2;
    border-radius: 6px;
    padding: 6px 8px;
    color: #2f2925;
    selection-background-color: #e7cfbf;
}

QLineEdit:focus,
QTextEdit:focus,
QPlainTextEdit:focus,
QComboBox:focus,
QSpinBox:focus,
QDoubleSpinBox:focus {
    border-color: #c96f4b;
    background-color: #ffffff;
}

QTextEdit[console="true"] {
    background-color: #fffaf5;
    border: 1px solid #ddd2c5;
    border-radius: 6px;
    padding: 8px;
    font-family: "Consolas", "Microsoft YaHei UI";
    font-size: 12px;
}

QComboBox::drop-down {
    border: none;
    width: 24px;
}

QComboBox::down-arrow {
    width: 10px;
    height: 10px;
}

QTabWidget::pane {
    border: 1px solid #ddd2c5;
    border-radius: 8px;
    background-color: #f9f4ee;
    top: -1px;
}

QTabBar::tab {
    background-color: #efe8de;
    border: 1px solid #ddd2c5;
    border-bottom: none;
    color: #7b6f64;
    border-top-left-radius: 8px;
    border-top-right-radius: 8px;
    padding: 10px 16px;
    margin-right: 4px;
}

QTabBar::tab:selected {
    background-color: #fbf7f2;
    color: #2c2622;
    border-color: #cfbcae;
}

QTabBar::tab:hover:!selected {
    color: #4a4039;
}

QPushButton {
    background-color: #f1e9df;
    border: 1px solid #d9cdc0;
    border-radius: 6px;
    padding: 7px 12px;
    color: #312a25;
    font-weight: 600;
}

QPushButton:hover {
    background-color: #f7efe6;
    border-color: #ccb7a5;
}

QPushButton:pressed {
    background-color: #eadfd3;
}

QPushButton#accentButton {
    background-color: #c56f47;
    border-color: #b6643d;
    color: #fffaf6;
}

QPushButton#accentButton:hover {
    background-color: #cf7b54;
    border-color: #c06d46;
}

QPushButton#dangerButton {
    background-color: #efe5e2;
    border-color: #d8c1bc;
    color: #8a5548;
}

QPushButton#dangerButton:hover {
    background-color: #f4ebe8;
    border-color: #ceb0a8;
}

QPushButton#ghostButton {
    background-color: transparent;
    border-color: #d9cec2;
    color: #7b6f64;
}

QToolButton {
    background-color: transparent;
    border: none;
    color: #2f2925;
    font-size: 15px;
    font-weight: 600;
    padding: 0px;
}

QToolButton:hover {
    color: #1f1a17;
}

QSlider::groove:horizontal {
    height: 6px;
    background-color: #e9dfd4;
    border: 1px solid #d7cbbd;
    border-radius: 3px;
}

QSlider::sub-page:horizontal {
    background-color: #cf8f72;
    border-radius: 3px;
}

QSlider::add-page:horizontal {
    background-color: #e9dfd4;
    border-radius: 3px;
}

QSlider::handle:horizontal {
    width: 18px;
    margin: -7px 0;
    border-radius: 9px;
    background-color: #fffaf6;
    border: 2px solid #c56f47;
}

QSlider::handle:horizontal:hover {
    border-color: #d58761;
}

QScrollArea {
    border: none;
    background-color: transparent;
}

QScrollBar:vertical {
    width: 12px;
    background: transparent;
    margin: 4px 0 4px 0;
}

QScrollBar::handle:vertical {
    background-color: #d9ccc0;
    border-radius: 6px;
    min-height: 28px;
}

QScrollBar::handle:vertical:hover {
    background-color: #c9b9aa;
}

QScrollBar::add-line:vertical,
QScrollBar::sub-line:vertical,
QScrollBar::add-page:vertical,
QScrollBar::sub-page:vertical {
    background: transparent;
    height: 0px;
}
"""

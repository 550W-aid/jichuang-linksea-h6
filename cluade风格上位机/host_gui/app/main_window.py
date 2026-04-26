from __future__ import annotations

import datetime as dt
from functools import partial
from pathlib import Path
from typing import Any

import serial.tools.list_ports
from PySide6.QtCore import QEasingCurve, QPointF, QRectF, QPropertyAnimation, QTimer, Qt, Signal, QVariantAnimation
from PySide6.QtGui import QColor, QCloseEvent, QMouseEvent, QPainter, QPen
from PySide6.QtWidgets import (
    QComboBox,
    QDoubleSpinBox,
    QFileDialog,
    QFormLayout,
    QFrame,
    QGraphicsOpacityEffect,
    QGridLayout,
    QHBoxLayout,
    QLabel,
    QLineEdit,
    QMainWindow,
    QMessageBox,
    QPushButton,
    QScrollArea,
    QSlider,
    QSpinBox,
    QTabWidget,
    QTextEdit,
    QToolButton,
    QVBoxLayout,
    QWidget,
)

from .protocol import (
    PacketType,
    VideoChunkConfig,
    build_algo_payload_csv,
    build_algo_payload_json,
    build_ccic_packet,
    chunk_frame_payload,
    parse_hex_string,
    to_hex_line,
)
from .styles import APP_QSS
from .workers import EthernetWorker, SerialConfig, SerialWorker, UdpConfig, VideoStreamConfig, VideoStreamWorker


class HoverCard(QFrame):
    def __init__(self, card_kind: str = "module", parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self.setProperty("card", card_kind)
        self.setProperty("hovered", False)
        self.setProperty("active", False)
        self.setMouseTracking(True)
        self.setAttribute(Qt.WA_Hover, True)

    def _set_state(self, name: str, value: bool) -> None:
        if self.property(name) == value:
            return
        self.setProperty(name, value)
        self.style().unpolish(self)
        self.style().polish(self)
        self.update()

    def enterEvent(self, event) -> None:
        self._set_state("hovered", True)
        super().enterEvent(event)

    def leaveEvent(self, event) -> None:
        self._set_state("hovered", False)
        super().leaveEvent(event)


class CollapsibleCard(HoverCard):
    def __init__(
        self,
        title: str,
        subtitle: str = "",
        *,
        expanded: bool = False,
        parent: QWidget | None = None,
    ) -> None:
        super().__init__("module", parent)
        self._expanded = expanded

        outer = QVBoxLayout(self)
        outer.setContentsMargins(16, 14, 16, 16)
        outer.setSpacing(10)

        header = QWidget()
        header_layout = QHBoxLayout(header)
        header_layout.setContentsMargins(0, 0, 0, 0)
        header_layout.setSpacing(10)

        self.toggle_button = QToolButton()
        self.toggle_button.setToolButtonStyle(Qt.ToolButtonStyle.ToolButtonTextBesideIcon)
        self.toggle_button.setArrowType(Qt.ArrowType.DownArrow if expanded else Qt.ArrowType.RightArrow)
        self.toggle_button.setText(title)
        self.toggle_button.setCheckable(True)
        self.toggle_button.setChecked(expanded)
        self.toggle_button.toggled.connect(self._set_expanded)
        header_layout.addWidget(self.toggle_button)
        header_layout.addStretch(1)
        outer.addWidget(header)

        self.subtitle_label = QLabel(subtitle)
        self.subtitle_label.setProperty("textRole", "sectionSubtitle")
        self.subtitle_label.setWordWrap(True)
        self.subtitle_label.setVisible(bool(subtitle))
        outer.addWidget(self.subtitle_label)

        self.content_widget = QWidget()
        self.content_widget.setVisible(expanded)
        self.content_layout = QVBoxLayout(self.content_widget)
        self.content_layout.setContentsMargins(0, 0, 0, 0)
        self.content_layout.setSpacing(12)
        outer.addWidget(self.content_widget)

    def _set_expanded(self, expanded: bool) -> None:
        self._expanded = expanded
        self.toggle_button.setArrowType(Qt.ArrowType.DownArrow if expanded else Qt.ArrowType.RightArrow)
        self.content_widget.setVisible(expanded)

    def isExpanded(self) -> bool:
        return self._expanded


class JoystickPad(QWidget):
    valueChanged = Signal(int, int)
    editingFinished = Signal()
    animationFinished = Signal()

    def __init__(self, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self._pan_x = 128
        self._pan_y = 128
        self._dragging = False
        self._invert_y = True
        self._anim_from = (128, 128)
        self._anim_to = (128, 128)
        self._return_anim = QVariantAnimation(self)
        self._return_anim.setEasingCurve(QEasingCurve.Type.OutCubic)
        self._return_anim.valueChanged.connect(self._on_anim_value_changed)
        self._return_anim.finished.connect(self.animationFinished.emit)
        self.setMinimumSize(188, 188)

    def value(self) -> tuple[int, int]:
        return self._pan_x, self._pan_y

    def setValue(self, pan_x: int, pan_y: int, *, emit_signal: bool = False) -> None:
        pan_x = max(0, min(255, int(pan_x)))
        pan_y = max(0, min(255, int(pan_y)))
        if (pan_x, pan_y) == (self._pan_x, self._pan_y):
            return
        self._pan_x = pan_x
        self._pan_y = pan_y
        self.update()
        if emit_signal:
            self.valueChanged.emit(self._pan_x, self._pan_y)

    def animate_to_value(self, pan_x: int, pan_y: int, duration_ms: int = 220) -> None:
        self._return_anim.stop()
        self._anim_from = self.value()
        self._anim_to = (
            max(0, min(255, int(pan_x))),
            max(0, min(255, int(pan_y))),
        )
        self._return_anim.setDuration(max(80, duration_ms))
        self._return_anim.setStartValue(0.0)
        self._return_anim.setEndValue(1.0)
        self._return_anim.start()

    def _on_anim_value_changed(self, value: Any) -> None:
        progress = float(value)
        start_x, start_y = self._anim_from
        end_x, end_y = self._anim_to
        pan_x = round(start_x + (end_x - start_x) * progress)
        pan_y = round(start_y + (end_y - start_y) * progress)
        self.setValue(pan_x, pan_y, emit_signal=True)

    def _pad_rect(self) -> QRectF:
        return QRectF(18.0, 18.0, max(1.0, self.width() - 36.0), max(1.0, self.height() - 36.0))

    def _set_from_pos(self, pos: QPointF, *, emit_signal: bool = True) -> None:
        rect = self._pad_rect()
        if rect.width() <= 1.0 or rect.height() <= 1.0:
            return
        self._return_anim.stop()
        x_norm = (pos.x() - rect.left()) / rect.width()
        y_norm = (pos.y() - rect.top()) / rect.height()
        x_norm = max(0.0, min(1.0, x_norm))
        y_norm = max(0.0, min(1.0, y_norm))
        pan_x = round(x_norm * 255.0)
        if self._invert_y:
            pan_y = round((1.0 - y_norm) * 255.0)
        else:
            pan_y = round(y_norm * 255.0)
        self.setValue(pan_x, pan_y, emit_signal=emit_signal)

    def mousePressEvent(self, event: QMouseEvent) -> None:
        if event.button() == Qt.MouseButton.LeftButton:
            self._dragging = True
            self._set_from_pos(event.position())
            event.accept()
            return
        super().mousePressEvent(event)

    def mouseMoveEvent(self, event: QMouseEvent) -> None:
        if self._dragging:
            self._set_from_pos(event.position())
            event.accept()
            return
        super().mouseMoveEvent(event)

    def mouseReleaseEvent(self, event: QMouseEvent) -> None:
        if self._dragging and event.button() == Qt.MouseButton.LeftButton:
            self._dragging = False
            self._set_from_pos(event.position())
            self.editingFinished.emit()
            event.accept()
            return
        super().mouseReleaseEvent(event)

    def paintEvent(self, _event) -> None:
        rect = self._pad_rect()
        cx = rect.left() + (rect.width() * self._pan_x / 255.0)
        if self._invert_y:
            cy = rect.top() + (rect.height() * (1.0 - self._pan_y / 255.0))
        else:
            cy = rect.top() + (rect.height() * self._pan_y / 255.0)

        painter = QPainter(self)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing, True)
        painter.fillRect(self.rect(), QColor("#fbf7f2"))

        painter.setPen(QPen(QColor("#ddd2c5"), 1.3))
        painter.setBrush(QColor("#fffaf5"))
        painter.drawRoundedRect(rect, 16.0, 16.0)

        painter.setPen(QPen(QColor("#d2c6b9"), 1.0, Qt.PenStyle.DashLine))
        painter.drawLine(QPointF(rect.center().x(), rect.top()), QPointF(rect.center().x(), rect.bottom()))
        painter.drawLine(QPointF(rect.left(), rect.center().y()), QPointF(rect.right(), rect.center().y()))

        painter.setPen(Qt.PenStyle.NoPen)
        painter.setBrush(QColor("#f2e6db"))
        painter.drawEllipse(QPointF(rect.center().x(), rect.center().y()), 30.0, 30.0)

        painter.setPen(QPen(QColor("#d7a188"), 1.4))
        painter.setBrush(QColor("#c77751"))
        painter.drawEllipse(QPointF(cx, cy), 15.0, 15.0)


class MainWindow(QMainWindow):
    def __init__(self) -> None:
        super().__init__()
        self.setWindowTitle("CCIC FPGA 上位机控制台")
        self.resize(1460, 920)

        self._pkt_seq = 0
        self._sweep_values: list[float] = []
        self._sweep_index = 0
        self._tx_packets = 0
        self._rx_packets = 0
        self._tx_bytes = 0
        self._rx_bytes = 0
        self._last_error = "无"
        self._serial_rx_buffer = bytearray()
        self._fade_animations: list[QPropertyAnimation] = []
        self._animated_cards: list[QWidget] = []
        self._pulse_timers: dict[int, QTimer] = {}
        self._view_pad_programmatic = False
        self.algorithm_card_map: dict[str, HoverCard] = {}
        self.module_value_map: dict[tuple[str, str], QLineEdit] = {}

        self.serial_worker = SerialWorker()
        self.eth_worker = EthernetWorker()
        self.video_worker = VideoStreamWorker()
        self.serial_worker.start()
        self.eth_worker.start()

        self._wire_workers()
        self._build_ui()
        self.packet_mode_combo.setCurrentIndex(0)
        self.algo_encode_combo.setCurrentIndex(1)
        self.algo_channel_combo.setCurrentIndex(1)
        self._refresh_serial_ports()

    def _wire_workers(self) -> None:
        self.serial_worker.rx.connect(self._on_serial_rx)
        self.serial_worker.status.connect(self._on_serial_status)
        self.serial_worker.error.connect(self._on_error_status)

        self.eth_worker.rx.connect(self._on_eth_rx)
        self.eth_worker.status.connect(self._on_eth_status)
        self.eth_worker.error.connect(self._on_error_status)

        self.video_worker.packet_ready.connect(self._on_video_packet)
        self.video_worker.status.connect(self._on_video_status)
        self.video_worker.error.connect(self._on_error_status)
        self.video_worker.frame_stat.connect(self._on_video_stat)

    def _register_animated_card(self, widget: QWidget) -> None:
        self._animated_cards.append(widget)

    def _set_widget_flag(self, widget: QWidget, name: str, value: bool) -> None:
        if widget.property(name) == value:
            return
        widget.setProperty(name, value)
        widget.style().unpolish(widget)
        widget.style().polish(widget)
        widget.update()

    def _pulse_card(self, widget: QWidget, duration_ms: int = 700) -> None:
        key = id(widget)
        timer = self._pulse_timers.get(key)
        if timer is None:
            timer = QTimer(self)
            timer.setSingleShot(True)
            timer.timeout.connect(partial(self._set_widget_flag, widget, "active", False))
            self._pulse_timers[key] = timer
        self._set_widget_flag(widget, "active", True)
        timer.start(duration_ms)

    def _set_badge_state(self, label: QLabel, text: str, state: str) -> None:
        label.setText(text)
        label.setProperty("badge", state)
        label.style().unpolish(label)
        label.style().polish(label)
        label.update()

    def _set_chip_state(self, label: QLabel, text: str, state: str) -> None:
        label.setText(text)
        label.setProperty("chip", state)
        label.style().unpolish(label)
        label.style().polish(label)
        label.update()

    def _create_role_label(self, text: str, role: str, *, word_wrap: bool = False) -> QLabel:
        label = QLabel(text)
        label.setProperty("textRole", role)
        label.setWordWrap(word_wrap)
        return label

    def _create_badge(self, text: str, state: str) -> QLabel:
        badge = QLabel(text)
        self._set_badge_state(badge, text, state)
        return badge

    def _create_chip(self, text: str, state: str) -> QLabel:
        chip = QLabel(text)
        self._set_chip_state(chip, text, state)
        return chip

    def _create_module_card(self, title: str, subtitle: str = "", *, card_kind: str = "module") -> tuple[HoverCard, QVBoxLayout]:
        card = HoverCard(card_kind)
        self._register_animated_card(card)
        layout = QVBoxLayout(card)
        if card_kind == "reserved":
            layout.setContentsMargins(14, 12, 14, 12)
            layout.setSpacing(8)
        else:
            layout.setContentsMargins(16, 14, 16, 16)
            layout.setSpacing(10)
        layout.addWidget(self._create_role_label(title, "sectionTitle"))
        if subtitle:
            layout.addWidget(self._create_role_label(subtitle, "sectionSubtitle", word_wrap=True))
        body = QVBoxLayout()
        body.setSpacing(8 if card_kind == "reserved" else 12)
        layout.addLayout(body)
        return card, body

    def _create_section_header(self, title: str, subtitle: str) -> QWidget:
        header = QFrame()
        header.setObjectName("SectionHeader")
        layout = QVBoxLayout(header)
        layout.setContentsMargins(2, 4, 2, 0)
        layout.setSpacing(4)
        layout.addWidget(self._create_role_label(title, "sectionTitle"))
        layout.addWidget(self._create_role_label(subtitle, "sectionSubtitle", word_wrap=True))
        return header

    def _register_algorithm_card(self, algorithm: str, card: HoverCard) -> None:
        self.algorithm_card_map[algorithm.strip().lower()] = card

    def _pulse_algorithm_card(self, algorithm: str) -> None:
        card = self.algorithm_card_map.get(algorithm.strip().lower())
        if card is not None:
            self._pulse_card(card)

    def _send_named_algo_param(self, algorithm: str, param: str, value_edit: QLineEdit, source_name: str) -> None:
        value = self._parse_numeric(value_edit.text())
        self._dispatch_algo_param(algorithm, param, value, show_dialog=True, source=f"{source_name}模块")

    def _build_reserved_algo_card(
        self,
        title: str,
        subtitle: str,
        algorithm: str,
        param: str,
        *,
        placeholder: str,
        default_value: str = "0",
    ) -> HoverCard:
        card, body = self._create_module_card(title, subtitle, card_kind="reserved")
        self._register_algorithm_card(algorithm, card)

        header = QHBoxLayout()
        header.addWidget(self._create_chip("预留接口", "neutral"))
        header.addStretch(1)
        body.addLayout(header)

        body.addWidget(self._create_role_label(f"主参数: {param}", "helper"))

        row = QHBoxLayout()
        value_edit = QLineEdit(default_value)
        value_edit.setPlaceholderText(placeholder)
        send_btn = QPushButton("发送")
        send_btn.setObjectName("ghostButton")
        send_btn.clicked.connect(partial(self._send_named_algo_param, algorithm, param, value_edit, title))
        row.addWidget(value_edit, 1)
        row.addWidget(send_btn)
        body.addLayout(row)

        self.module_value_map[(algorithm.strip().lower(), param.strip().lower())] = value_edit
        return card

    def _build_ui(self) -> None:
        self.setStyleSheet(APP_QSS)

        root = QWidget()
        root.setObjectName("CentralRoot")
        root_layout = QVBoxLayout(root)
        root_layout.setContentsMargins(14, 14, 14, 14)
        root_layout.setSpacing(12)

        banner = HoverCard("banner")
        self._register_animated_card(banner)
        banner_layout = QHBoxLayout(banner)
        banner_layout.setContentsMargins(18, 14, 18, 14)
        banner_layout.setSpacing(18)

        banner_text = QVBoxLayout()
        banner_text.setSpacing(4)
        banner_text.addWidget(self._create_role_label("CCIC FPGA 上位机控制台", "title"))
        banner_text.addWidget(self._create_role_label("串口、网络、媒体传输与算法参数控制集中在同一工作台内。", "subtitle"))
        banner_text.addWidget(self._create_role_label("当前布局强调常用算法控制，保留高级参数入口用于调试与扩展。", "bannerNote"))
        self.clock_label = self._create_role_label("", "bannerNote")
        banner_text.addWidget(self.clock_label)
        banner_text.addStretch(1)
        banner_layout.addLayout(banner_text, 2)

        status_grid = QGridLayout()
        status_grid.setHorizontalSpacing(10)
        status_grid.setVerticalSpacing(8)
        serial_card, self.card_serial_value = self._build_status_card("串口", "离线")
        eth_card, self.card_eth_value = self._build_status_card("网络", "离线")
        video_card, self.card_video_value = self._build_status_card("视频", "空闲")
        flow_card, self.card_flow_value = self._build_status_card("流量", "发送 0.0 KB | 接收 0.0 KB")
        status_grid.addWidget(serial_card, 0, 0)
        status_grid.addWidget(eth_card, 0, 1)
        status_grid.addWidget(video_card, 0, 2)
        status_grid.addWidget(flow_card, 0, 3)
        status_grid.setColumnStretch(0, 1)
        status_grid.setColumnStretch(1, 1)
        status_grid.setColumnStretch(2, 1)
        status_grid.setColumnStretch(3, 2)
        status_wrap = QWidget()
        status_wrap.setLayout(status_grid)
        banner_layout.addWidget(status_wrap, 3)
        root_layout.addWidget(banner)

        body_layout = QHBoxLayout()
        body_layout.setSpacing(12)
        root_layout.addLayout(body_layout, 1)

        left_panel = self._build_left_panel()
        left_panel.setFixedWidth(328)
        body_layout.addWidget(left_panel, 0)

        self.tabs = QTabWidget()
        self.tabs.setDocumentMode(True)
        self.tabs.addTab(self._build_serial_tab(), "串口控制")
        self.tabs.addTab(self._build_eth_tab(), "以太网")
        self.tabs.addTab(self._build_media_tab(), "图像 / 视频")
        self.tabs.addTab(self._build_algo_tab(), "算法控制")
        self.tabs.addTab(self._build_log_tab(), "系统日志")
        body_layout.addWidget(self.tabs, 1)

        self.setCentralWidget(root)

        self._refresh_dashboard()
        self._update_clock()
        self.clock_timer = QTimer(self)
        self.clock_timer.timeout.connect(self._update_clock)
        self.clock_timer.start(1000)
        QTimer.singleShot(60, self._start_intro_animation)

    def _start_intro_animation(self) -> None:
        self._fade_animations.clear()
        for index, card in enumerate(self._animated_cards):
            effect = QGraphicsOpacityEffect(card)
            effect.setOpacity(0.0)
            card.setGraphicsEffect(effect)
            animation = QPropertyAnimation(effect, b"opacity", self)
            animation.setDuration(240)
            animation.setStartValue(0.0)
            animation.setEndValue(1.0)
            animation.setEasingCurve(QEasingCurve.Type.OutCubic)
            self._fade_animations.append(animation)
            QTimer.singleShot(index * 35, animation.start)

    def _build_status_card(self, title: str, value: str) -> tuple[HoverCard, QLabel]:
        card = HoverCard("status")
        self._register_animated_card(card)
        layout = QVBoxLayout(card)
        layout.setContentsMargins(12, 8, 12, 8)
        layout.setSpacing(4)
        layout.addWidget(self._create_role_label(title, "statusTitle"))
        value_label = self._create_role_label(value, "statusValue")
        value_label.setWordWrap(True)
        layout.addWidget(value_label)
        return card, value_label

    def _build_left_panel(self) -> QWidget:
        panel = QWidget()
        layout = QVBoxLayout(panel)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(12)

        serial_card, serial_body = self._create_module_card("串口连接", "连接板载串口并查看调试输出。")
        serial_form = QFormLayout()
        serial_form.setContentsMargins(0, 0, 0, 0)
        serial_form.setSpacing(10)

        self.serial_port_combo = QComboBox()
        self.serial_refresh_btn = QPushButton("刷新")
        self.serial_refresh_btn.setObjectName("ghostButton")
        self.serial_refresh_btn.clicked.connect(self._refresh_serial_ports)
        port_row = QWidget()
        port_row_layout = QHBoxLayout(port_row)
        port_row_layout.setContentsMargins(0, 0, 0, 0)
        port_row_layout.setSpacing(8)
        port_row_layout.addWidget(self.serial_port_combo, 1)
        port_row_layout.addWidget(self.serial_refresh_btn)
        serial_form.addRow("串口", port_row)

        self.serial_baud = QComboBox()
        for baud in ("9600", "57600", "115200", "230400", "460800", "921600"):
            self.serial_baud.addItem(baud, int(baud))
        self.serial_baud.setCurrentText("115200")
        serial_form.addRow("波特率", self.serial_baud)

        self.serial_status_badge = self._create_badge("离线", "offline")
        serial_form.addRow("状态", self.serial_status_badge)
        serial_body.addLayout(serial_form)

        serial_buttons = QHBoxLayout()
        self.serial_open_btn = QPushButton("连接")
        self.serial_open_btn.setObjectName("accentButton")
        self.serial_close_btn = QPushButton("断开")
        self.serial_close_btn.setObjectName("dangerButton")
        self.serial_open_btn.clicked.connect(self._open_serial)
        self.serial_close_btn.clicked.connect(self._close_serial)
        serial_buttons.addWidget(self.serial_open_btn)
        serial_buttons.addWidget(self.serial_close_btn)
        serial_body.addLayout(serial_buttons)
        layout.addWidget(serial_card)

        eth_card, eth_body = self._create_module_card("网络连接", "配置 UDP 收发地址，用于图像、视频与算法参数传输。")
        eth_form = QFormLayout()
        eth_form.setContentsMargins(0, 0, 0, 0)
        eth_form.setSpacing(10)

        self.bind_ip_edit = QLineEdit("0.0.0.0")
        self.bind_port_spin = QSpinBox()
        self.bind_port_spin.setRange(1, 65535)
        self.bind_port_spin.setValue(5000)
        self.remote_ip_edit = QLineEdit("192.168.1.10")
        self.remote_port_spin = QSpinBox()
        self.remote_port_spin.setRange(1, 65535)
        self.remote_port_spin.setValue(6000)
        eth_form.addRow("本地 IP", self.bind_ip_edit)
        eth_form.addRow("本地端口", self.bind_port_spin)
        eth_form.addRow("目标 IP", self.remote_ip_edit)
        eth_form.addRow("目标端口", self.remote_port_spin)
        self.eth_status_badge = self._create_badge("离线", "offline")
        eth_form.addRow("状态", self.eth_status_badge)
        eth_body.addLayout(eth_form)

        eth_buttons = QHBoxLayout()
        self.eth_open_btn = QPushButton("连接")
        self.eth_open_btn.setObjectName("accentButton")
        self.eth_close_btn = QPushButton("关闭")
        self.eth_close_btn.setObjectName("dangerButton")
        self.eth_open_btn.clicked.connect(self._open_eth)
        self.eth_close_btn.clicked.connect(self._close_eth)
        eth_buttons.addWidget(self.eth_open_btn)
        eth_buttons.addWidget(self.eth_close_btn)
        eth_body.addLayout(eth_buttons)
        layout.addWidget(eth_card)

        packet_card, packet_body = self._create_module_card("封包与文本格式", "在协议封装和原始字节发送之间快速切换。")
        packet_form = QFormLayout()
        packet_form.setContentsMargins(0, 0, 0, 0)
        packet_form.setSpacing(10)
        self.packet_mode_combo = QComboBox()
        self.packet_mode_combo.addItem("原始数据", "raw")
        self.packet_mode_combo.addItem("CCICv1", "ccicv1")
        self.text_format_combo = QComboBox()
        self.text_format_combo.addItem("ASCII 文本", "ascii")
        self.text_format_combo.addItem("HEX 字节", "hex")
        packet_form.addRow("封包模式", self.packet_mode_combo)
        packet_form.addRow("文本格式", self.text_format_combo)
        packet_body.addLayout(packet_form)
        layout.addWidget(packet_card)

        layout.addStretch(1)
        return panel

    def _build_serial_tab(self) -> QWidget:
        page = QWidget()
        layout = QVBoxLayout(page)
        layout.setContentsMargins(14, 14, 14, 14)
        layout.setSpacing(12)

        rx_card, rx_body = self._create_module_card("串口接收", "按行显示可打印文本，其他内容显示为十六进制。")
        self.serial_rx_text = QTextEdit()
        self.serial_rx_text.setReadOnly(True)
        self.serial_rx_text.setProperty("console", True)
        self.serial_rx_text.setPlaceholderText("串口接收数据将在这里滚动显示。")
        rx_body.addWidget(self.serial_rx_text)
        layout.addWidget(rx_card, 1)

        tx_card, tx_body = self._create_module_card("串口发送", "支持 ASCII 与 HEX 两种输入格式。")
        tx_row = QHBoxLayout()
        self.serial_tx_edit = QLineEdit()
        self.serial_tx_edit.setPlaceholderText("输入待发送内容")
        self.serial_send_btn = QPushButton("发送")
        self.serial_send_btn.setObjectName("accentButton")
        self.serial_send_btn.clicked.connect(self._send_serial_text)
        clear_btn = QPushButton("清空")
        clear_btn.setObjectName("ghostButton")
        clear_btn.clicked.connect(self.serial_rx_text.clear)
        tx_row.addWidget(self.serial_tx_edit, 1)
        tx_row.addWidget(self.serial_send_btn)
        tx_row.addWidget(clear_btn)
        tx_body.addLayout(tx_row)
        layout.addWidget(tx_card, 0)
        return page

    def _build_eth_tab(self) -> QWidget:
        page = QWidget()
        layout = QVBoxLayout(page)
        layout.setContentsMargins(14, 14, 14, 14)
        layout.setSpacing(12)

        rx_card, rx_body = self._create_module_card("网络接收", "显示最近收到的 UDP 数据包摘要。")
        self.eth_rx_text = QTextEdit()
        self.eth_rx_text.setReadOnly(True)
        self.eth_rx_text.setProperty("console", True)
        self.eth_rx_text.setPlaceholderText("网络接收数据将在这里显示。")
        rx_body.addWidget(self.eth_rx_text)
        layout.addWidget(rx_card, 1)

        tx_card, tx_body = self._create_module_card("网络发送", "通过当前的 UDP 配置发送命令或测试数据。")
        tx_row = QHBoxLayout()
        self.eth_tx_edit = QLineEdit()
        self.eth_tx_edit.setPlaceholderText("输入待发送内容")
        self.eth_send_btn = QPushButton("发送")
        self.eth_send_btn.setObjectName("accentButton")
        self.eth_send_btn.clicked.connect(self._send_eth_text)
        clear_btn = QPushButton("清空")
        clear_btn.setObjectName("ghostButton")
        clear_btn.clicked.connect(self.eth_rx_text.clear)
        tx_row.addWidget(self.eth_tx_edit, 1)
        tx_row.addWidget(self.eth_send_btn)
        tx_row.addWidget(clear_btn)
        tx_body.addLayout(tx_row)
        layout.addWidget(tx_card, 0)
        return page

    def _build_media_tab(self) -> QWidget:
        page = QWidget()
        layout = QVBoxLayout(page)
        layout.setContentsMargins(14, 14, 14, 14)
        layout.setSpacing(12)

        image_card, image_body = self._create_module_card("图片发送", "将单张图片切片后通过 UDP 发送到 FPGA。")
        image_grid = QGridLayout()
        image_grid.setHorizontalSpacing(10)
        image_grid.setVerticalSpacing(10)
        self.image_path_edit = QLineEdit()
        self.image_path_edit.setPlaceholderText("选择图片文件 (*.png *.jpg *.bmp)")
        browse_btn = QPushButton("浏览")
        browse_btn.setObjectName("ghostButton")
        browse_btn.clicked.connect(self._browse_image)
        send_img_btn = QPushButton("发送图片")
        send_img_btn.setObjectName("accentButton")
        send_img_btn.clicked.connect(self._send_image_file)
        self.image_chunk_spin = QSpinBox()
        self.image_chunk_spin.setRange(256, 60000)
        self.image_chunk_spin.setValue(1200)
        image_grid.addWidget(QLabel("图片文件"), 0, 0)
        image_grid.addWidget(self.image_path_edit, 0, 1, 1, 2)
        image_grid.addWidget(browse_btn, 0, 3)
        image_grid.addWidget(QLabel("分片载荷"), 1, 0)
        image_grid.addWidget(self.image_chunk_spin, 1, 1)
        image_grid.addWidget(send_img_btn, 1, 3)
        image_body.addLayout(image_grid)
        layout.addWidget(image_card)

        video_card, video_body = self._create_module_card("视频推流", "支持摄像头或文件源，按设定帧率与 JPEG 质量推流。")
        video_grid = QGridLayout()
        video_grid.setHorizontalSpacing(10)
        video_grid.setVerticalSpacing(10)
        self.video_source_edit = QLineEdit("0")
        self.video_source_edit.setPlaceholderText("摄像头编号或视频文件路径")
        self.video_fps_spin = QSpinBox()
        self.video_fps_spin.setRange(1, 120)
        self.video_fps_spin.setValue(30)
        self.video_quality_spin = QSpinBox()
        self.video_quality_spin.setRange(10, 95)
        self.video_quality_spin.setValue(70)
        self.video_chunk_spin = QSpinBox()
        self.video_chunk_spin.setRange(256, 60000)
        self.video_chunk_spin.setValue(1200)
        self.video_w_spin = QSpinBox()
        self.video_w_spin.setRange(0, 4096)
        self.video_w_spin.setValue(0)
        self.video_h_spin = QSpinBox()
        self.video_h_spin.setRange(0, 4096)
        self.video_h_spin.setValue(0)
        self.video_stat_label = self._create_role_label("FPS: 0 | 最近帧字节数: 0", "helper")
        start_btn = QPushButton("开始推流")
        start_btn.setObjectName("accentButton")
        stop_btn = QPushButton("停止推流")
        stop_btn.setObjectName("dangerButton")
        start_btn.clicked.connect(self._start_video_stream)
        stop_btn.clicked.connect(self._stop_video_stream)

        video_grid.addWidget(QLabel("输入源"), 0, 0)
        video_grid.addWidget(self.video_source_edit, 0, 1, 1, 3)
        video_grid.addWidget(QLabel("帧率 FPS"), 1, 0)
        video_grid.addWidget(self.video_fps_spin, 1, 1)
        video_grid.addWidget(QLabel("JPEG 质量"), 1, 2)
        video_grid.addWidget(self.video_quality_spin, 1, 3)
        video_grid.addWidget(QLabel("分片载荷"), 2, 0)
        video_grid.addWidget(self.video_chunk_spin, 2, 1)
        video_grid.addWidget(QLabel("缩放宽度"), 2, 2)
        video_grid.addWidget(self.video_w_spin, 2, 3)
        video_grid.addWidget(QLabel("缩放高度"), 3, 2)
        video_grid.addWidget(self.video_h_spin, 3, 3)
        video_grid.addWidget(start_btn, 3, 0)
        video_grid.addWidget(stop_btn, 3, 1)
        video_grid.addWidget(self.video_stat_label, 4, 0, 1, 4)
        video_body.addLayout(video_grid)
        layout.addWidget(video_card)
        layout.addStretch(1)
        return page

    def _build_algo_tab(self) -> QWidget:
        page = QWidget()
        outer = QVBoxLayout(page)
        outer.setContentsMargins(14, 14, 14, 14)
        outer.setSpacing(0)

        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QFrame.Shape.NoFrame)
        outer.addWidget(scroll)

        container = QWidget()
        main_layout = QVBoxLayout(container)
        main_layout.setContentsMargins(0, 0, 0, 0)
        main_layout.setSpacing(12)
        scroll.setWidget(container)

        main_layout.addWidget(
            self._create_section_header(
                "常用算法",
                "把当前已经接到 FPGA 的核心控制放在最前面，便于现场调参与联调。",
            )
        )

        control_grid = QGridLayout()
        control_grid.setHorizontalSpacing(12)
        control_grid.setVerticalSpacing(12)
        control_grid.setColumnStretch(0, 2)
        control_grid.setColumnStretch(1, 2)
        control_grid.setColumnStretch(2, 2)

        self.zoom_card, zoom_body = self._create_module_card(
            "缩放",
            "单条双向滑条统一控制缩小与放大，中点回到原始视图。"
        )
        self._register_algorithm_card("resize", self.zoom_card)
        self._register_algorithm_card("zoom_in", self.zoom_card)
        zoom_header = QHBoxLayout()
        self.zoom_mode_chip = self._create_chip("原始视图", "neutral")
        zoom_header.addWidget(self.zoom_mode_chip)
        zoom_header.addStretch(1)
        zoom_body.addLayout(zoom_header)

        self.zoom_value_label = self._create_role_label("", "statusValue")
        self.zoom_detail_label = self._create_role_label("", "helper", word_wrap=True)
        zoom_body.addWidget(self.zoom_value_label)
        zoom_body.addWidget(self.zoom_detail_label)

        self.zoom_slider = QSlider(Qt.Orientation.Horizontal)
        self.zoom_slider.setRange(-255, 255)
        self.zoom_slider.setSingleStep(1)
        self.zoom_slider.setPageStep(16)
        self.zoom_slider.setTickInterval(32)
        self.zoom_slider.setValue(0)
        self.zoom_slider.valueChanged.connect(self._on_zoom_slider_changed)
        self.zoom_slider.sliderReleased.connect(self._flush_zoom_slider)
        zoom_body.addWidget(self.zoom_slider)

        zoom_legend = QHBoxLayout()
        zoom_legend.addWidget(self._create_role_label("缩小", "helper"))
        zoom_legend.addStretch(1)
        zoom_legend.addWidget(self._create_role_label("原始", "helper"))
        zoom_legend.addStretch(1)
        zoom_legend.addWidget(self._create_role_label("放大", "helper"))
        zoom_body.addLayout(zoom_legend)

        zoom_actions = QHBoxLayout()
        self.zoom_reset_btn = QPushButton("回到原始")
        self.zoom_reset_btn.setObjectName("ghostButton")
        self.zoom_reset_btn.clicked.connect(self._reset_zoom_slider)
        zoom_actions.addStretch(1)
        zoom_actions.addWidget(self.zoom_reset_btn)
        zoom_body.addLayout(zoom_actions)

        self.zoom_slider_timer = QTimer(self)
        self.zoom_slider_timer.setSingleShot(True)
        self.zoom_slider_timer.timeout.connect(self._flush_zoom_slider)
        control_grid.addWidget(self.zoom_card, 0, 0, 1, 2)

        self.lowlight_card, lowlight_body = self._create_module_card(
            "低照增强",
            "线性控制增强强度，便于快速验证夜间或暗场效果。"
        )
        self._register_algorithm_card("lowlight", self.lowlight_card)
        lowlight_header = QHBoxLayout()
        self.lowlight_state_chip = self._create_chip("关闭", "neutral")
        lowlight_header.addWidget(self.lowlight_state_chip)
        lowlight_header.addStretch(1)
        lowlight_body.addLayout(lowlight_header)

        self.lowlight_value_label = self._create_role_label("", "statusValue")
        lowlight_body.addWidget(self.lowlight_value_label)

        self.lowlight_slider = QSlider(Qt.Orientation.Horizontal)
        self.lowlight_slider.setRange(0, 255)
        self.lowlight_slider.setSingleStep(1)
        self.lowlight_slider.setPageStep(8)
        self.lowlight_slider.setTickInterval(16)
        self.lowlight_slider.setValue(0)
        self.lowlight_slider.valueChanged.connect(self._on_lowlight_slider_changed)
        self.lowlight_slider.sliderReleased.connect(self._flush_lowlight_slider)
        lowlight_body.addWidget(self.lowlight_slider)
        lowlight_body.addWidget(self._create_role_label("0 代表关闭，数值越大增强越强。", "helper"))

        lowlight_actions = QHBoxLayout()
        self.lowlight_reset_btn = QPushButton("清零")
        self.lowlight_reset_btn.setObjectName("ghostButton")
        self.lowlight_reset_btn.clicked.connect(self._reset_lowlight_slider)
        lowlight_actions.addStretch(1)
        lowlight_actions.addWidget(self.lowlight_reset_btn)
        lowlight_body.addLayout(lowlight_actions)

        self.lowlight_slider_timer = QTimer(self)
        self.lowlight_slider_timer.setSingleShot(True)
        self.lowlight_slider_timer.timeout.connect(self._flush_lowlight_slider)
        control_grid.addWidget(self.lowlight_card, 1, 0, 1, 2)

        self.view_card, view_body = self._create_module_card(
            "视野 / 平移",
            "摇杆方向已按画面方向校正：上推为画面上移，下拉为画面下移。"
        )
        self._register_algorithm_card("view", self.view_card)
        view_row = QHBoxLayout()
        view_row.setSpacing(14)
        self.view_pad = JoystickPad()
        self.view_pad.setFixedSize(176, 176)
        self.view_pad.valueChanged.connect(self._on_view_pad_changed)
        self.view_pad.editingFinished.connect(self._flush_view_pad)
        self.view_pad.animationFinished.connect(self._on_view_pad_animation_finished)
        view_row.addWidget(self.view_pad, 0)

        view_info = QVBoxLayout()
        self.view_pad_label = self._create_role_label("", "statusValue")
        self.view_hint_label = self._create_role_label("左 / 右控制水平视野，上 / 下控制垂直视野。", "helper", word_wrap=True)
        view_info.addWidget(self.view_pad_label)
        view_info.addWidget(self.view_hint_label)
        view_info.addStretch(1)
        self.view_center_btn = QPushButton("Center")
        self.view_center_btn.setObjectName("ghostButton")
        self.view_center_btn.clicked.connect(self._reset_view_pad)
        view_info.addWidget(self.view_center_btn, 0, Qt.AlignmentFlag.AlignLeft)
        view_row.addLayout(view_info, 1)
        view_body.addLayout(view_row)

        self.view_pad_timer = QTimer(self)
        self.view_pad_timer.setSingleShot(True)
        self.view_pad_timer.timeout.connect(self._flush_view_pad)
        control_grid.addWidget(self.view_card, 0, 2, 2, 1)
        main_layout.addLayout(control_grid)

        main_layout.addWidget(
            self._create_section_header(
                "预留算法",
                "先把未来要接的算法模块位排整齐，后续接线时不用再推翻页面结构。",
            )
        )

        reserve_grid = QGridLayout()
        reserve_grid.setHorizontalSpacing(10)
        reserve_grid.setVerticalSpacing(10)
        for column in range(4):
            reserve_grid.setColumnStretch(column, 1)

        reserved_defs = [
            ("直方图均衡", "预留 LUT / CDF 映射强度入口。", "hist_eq", "strength", "强度，例如 64", "0"),
            ("旋转", "预留角度控制入口。", "rotate", "angle_deg", "角度，例如 15", "0"),
            ("仿射", "预留几何变换主控参数。", "affine", "angle_deg", "角度或主控参数", "0"),
            ("HDR", "预留高动态增强强度。", "hdr", "strength", "强度，例如 32", "0"),
            ("Gamma", "预留亮度曲线微调。", "gamma", "gamma", "Gamma，例如 1.2", "1.0"),
            ("锐化", "预留边缘细节增强。", "sharpen", "strength", "强度，例如 16", "0"),
            ("去噪", "预留基础降噪强度。", "denoise", "strength", "强度，例如 12", "0"),
            ("双边滤波", "预留边缘保留平滑。", "bilateral", "sigma", "sigma，例如 12", "0"),
            ("Guided", "预留导向滤波 eps。", "guided", "eps", "eps，例如 0.01", "0.01"),
            ("颜色校正", "预留白平衡 / 偏色微调。", "color_balance", "bias", "偏置，例如 0", "0"),
            ("边缘检测", "预留阈值控制。", "edge_detect", "threshold", "阈值，例如 96", "96"),
            ("数字识别", "预留识别阈值入口。", "digit_recognition", "threshold", "阈值，例如 128", "128"),
        ]
        for index, (title, subtitle, algorithm, param, placeholder, default_value) in enumerate(reserved_defs):
            card = self._build_reserved_algo_card(
                title,
                subtitle,
                algorithm,
                param,
                placeholder=placeholder,
                default_value=default_value,
            )
            reserve_grid.addWidget(card, index // 4, index % 4)
        main_layout.addLayout(reserve_grid)

        main_layout.addWidget(
            self._create_section_header(
                "调试与扩展",
                "高级参数与自动扫描保留在后面，日常操作不打断常用算法区。",
            )
        )

        self.advanced_card = CollapsibleCard(
            "高级参数",
            "保留原始参数发送能力，用于协议级调试与预留算法控制。",
            expanded=False,
        )
        self._register_animated_card(self.advanced_card)
        advanced_top = QGridLayout()
        advanced_top.setHorizontalSpacing(10)
        advanced_top.setVerticalSpacing(10)
        self.algo_encode_combo = QComboBox()
        self.algo_encode_combo.addItem("JSON", "json")
        self.algo_encode_combo.addItem("CSV", "csv")
        self.algo_channel_combo = QComboBox()
        self.algo_channel_combo.addItem("以太网", "ethernet")
        self.algo_channel_combo.addItem("串口", "serial")
        advanced_top.addWidget(QLabel("编码"), 0, 0)
        advanced_top.addWidget(self.algo_encode_combo, 0, 1)
        advanced_top.addWidget(QLabel("通道"), 0, 2)
        advanced_top.addWidget(self.algo_channel_combo, 0, 3)
        self.advanced_card.content_layout.addLayout(advanced_top)

        self.param_rows: list[tuple[str, QLineEdit, QLineEdit]] = []
        self.param_value_map: dict[tuple[str, str], QLineEdit] = {}
        row_defs = [
            ("resize", "scale"),
            ("zoom_in", "level"),
            ("view", "pan_x"),
            ("view", "pan_y"),
            ("hist_eq", "strength"),
            ("rotate", "angle_deg"),
            ("affine", "angle_deg"),
            ("lowlight", "gain"),
            ("hdr", "strength"),
            ("gamma", "gamma"),
            ("sharpen", "strength"),
            ("denoise", "strength"),
            ("bilateral", "sigma"),
            ("guided", "eps"),
            ("color_balance", "bias"),
            ("edge_detect", "threshold"),
            ("digit_recognition", "threshold"),
        ]
        param_grid = QGridLayout()
        param_grid.setHorizontalSpacing(8)
        param_grid.setVerticalSpacing(8)
        for row, (alg, param) in enumerate(row_defs, start=0):
            alg_edit = QLineEdit(alg)
            param_edit = QLineEdit(param)
            value_edit = QLineEdit()
            value_edit.setPlaceholderText("参数值")
            send_btn = QPushButton("发送")
            send_btn.setObjectName("ghostButton")
            send_btn.clicked.connect(partial(self._send_algo_param, alg_edit, param_edit, value_edit))
            param_grid.addWidget(alg_edit, row, 0)
            param_grid.addWidget(param_edit, row, 1)
            param_grid.addWidget(value_edit, row, 2)
            param_grid.addWidget(send_btn, row, 3)
            self.param_rows.append((alg, param_edit, value_edit))
            self.param_value_map[(alg, param)] = value_edit
        self.advanced_card.content_layout.addLayout(param_grid)
        main_layout.addWidget(self.advanced_card)

        self.sweep_card, sweep_body = self._create_module_card(
            "参数扫描",
            "按区间自动发送连续参数，用于调试响应曲线或寻找合适工作点。"
        )
        sweep_grid = QGridLayout()
        sweep_grid.setHorizontalSpacing(10)
        sweep_grid.setVerticalSpacing(10)
        self.sweep_alg_combo = QComboBox()
        self.sweep_alg_combo.addItems(list(dict.fromkeys(alg for alg, _ in row_defs)))
        self.sweep_param_edit = QLineEdit("value")
        self.sweep_start = QDoubleSpinBox()
        self.sweep_end = QDoubleSpinBox()
        self.sweep_step = QDoubleSpinBox()
        for spin in (self.sweep_start, self.sweep_end, self.sweep_step):
            spin.setDecimals(4)
            spin.setRange(-100000.0, 100000.0)
        self.sweep_start.setValue(0.0)
        self.sweep_end.setValue(90.0)
        self.sweep_step.setValue(5.0)
        self.sweep_interval = QSpinBox()
        self.sweep_interval.setRange(10, 5000)
        self.sweep_interval.setValue(100)
        self.sweep_status = self._create_chip("空闲", "neutral")

        sweep_start_btn = QPushButton("开始扫描")
        sweep_start_btn.setObjectName("accentButton")
        sweep_stop_btn = QPushButton("停止扫描")
        sweep_stop_btn.setObjectName("dangerButton")
        sweep_start_btn.clicked.connect(self._start_sweep)
        sweep_stop_btn.clicked.connect(self._stop_sweep)

        sweep_grid.addWidget(QLabel("算法"), 0, 0)
        sweep_grid.addWidget(self.sweep_alg_combo, 0, 1)
        sweep_grid.addWidget(QLabel("参数名"), 0, 2)
        sweep_grid.addWidget(self.sweep_param_edit, 0, 3)
        sweep_grid.addWidget(QLabel("起始值"), 1, 0)
        sweep_grid.addWidget(self.sweep_start, 1, 1)
        sweep_grid.addWidget(QLabel("结束值"), 1, 2)
        sweep_grid.addWidget(self.sweep_end, 1, 3)
        sweep_grid.addWidget(QLabel("步进"), 2, 0)
        sweep_grid.addWidget(self.sweep_step, 2, 1)
        sweep_grid.addWidget(QLabel("间隔 (ms)"), 2, 2)
        sweep_grid.addWidget(self.sweep_interval, 2, 3)
        sweep_grid.addWidget(sweep_start_btn, 3, 0, 1, 2)
        sweep_grid.addWidget(sweep_stop_btn, 3, 2, 1, 2)
        sweep_grid.addWidget(self.sweep_status, 4, 0, 1, 4)
        sweep_body.addLayout(sweep_grid)
        main_layout.addWidget(self.sweep_card)
        main_layout.addStretch(1)

        self.sweep_timer = QTimer(self)
        self.sweep_timer.timeout.connect(self._on_sweep_tick)
        self._update_zoom_slider_label(0)
        self._update_lowlight_slider_label(0)
        self._update_view_pad_label(*self.view_pad.value())
        return page

    def _build_log_tab(self) -> QWidget:
        page = QWidget()
        layout = QVBoxLayout(page)
        layout.setContentsMargins(14, 14, 14, 14)
        layout.setSpacing(12)

        log_card, log_body = self._create_module_card("系统日志", "集中记录连接状态、收发事件与错误信息。")
        self.log_text = QTextEdit()
        self.log_text.setReadOnly(True)
        self.log_text.setProperty("console", True)
        log_body.addWidget(self.log_text)

        actions = QHBoxLayout()
        actions.addStretch(1)
        clear_btn = QPushButton("清空日志")
        clear_btn.setObjectName("ghostButton")
        clear_btn.clicked.connect(self.log_text.clear)
        actions.addWidget(clear_btn)
        log_body.addLayout(actions)
        layout.addWidget(log_card)
        return page

    def _refresh_serial_ports(self) -> None:
        port_infos = list(serial.tools.list_ports.comports())
        current_port = self.serial_port_combo.currentData() or self.serial_port_combo.currentText().strip()

        def _score_port(port_info: Any) -> tuple[int, str]:
            desc = (port_info.description or "").lower()
            score = 0
            if "ch340" in desc or "usb-serial" in desc:
                score += 100
            if "ch347" in desc:
                score -= 40
            if "bluetooth" in desc or "蓝牙" in desc:
                score -= 100
            return (-score, port_info.device)

        port_infos.sort(key=_score_port)
        self.serial_port_combo.clear()
        for port_info in port_infos:
            label = f"{port_info.device}  {port_info.description}" if port_info.description else port_info.device
            self.serial_port_combo.addItem(label, port_info.device)
        if port_infos:
            selected_index = 0
            for index in range(self.serial_port_combo.count()):
                if self.serial_port_combo.itemData(index) == current_port:
                    selected_index = index
                    break
            self.serial_port_combo.setCurrentIndex(selected_index)
        else:
            self.serial_port_combo.addItem("未发现串口", "")
        ports = [port_info.device for port_info in port_infos]
        self._log("界面", f"串口列表已刷新: {ports if ports else '无'}")

    def _open_serial(self) -> None:
        port = (self.serial_port_combo.currentData() or self.serial_port_combo.currentText()).strip()
        if not port or port == "未发现串口":
            self._warn("未选择有效串口。")
            return
        self._serial_rx_buffer.clear()
        cfg = SerialConfig(port=port, baudrate=int(self.serial_baud.currentData() or self.serial_baud.currentText()))
        self.serial_worker.open_port(cfg)

    def _close_serial(self) -> None:
        self.serial_worker.close_port()
        self._serial_rx_buffer.clear()
        self._set_serial_badge(False)

    def _open_eth(self) -> None:
        cfg = UdpConfig(
            bind_ip=self.bind_ip_edit.text().strip(),
            bind_port=int(self.bind_port_spin.value()),
            remote_ip=self.remote_ip_edit.text().strip(),
            remote_port=int(self.remote_port_spin.value()),
        )
        self.eth_worker.configure_udp(cfg)

    def _close_eth(self) -> None:
        self.eth_worker.close_socket()
        self._set_eth_badge(False)

    def _set_serial_badge(self, online: bool) -> None:
        self._set_badge_state(self.serial_status_badge, "在线" if online else "离线", "online" if online else "offline")

    def _set_eth_badge(self, online: bool) -> None:
        self._set_badge_state(self.eth_status_badge, "在线" if online else "离线", "online" if online else "offline")

    def _on_serial_status(self, msg: str) -> None:
        self._log("串口", msg)
        low = msg.lower()
        if "connected" in low:
            self._set_serial_badge(True)
        elif "disconnected" in low or "close" in low:
            self._set_serial_badge(False)
        self._refresh_dashboard()

    def _on_eth_status(self, msg: str) -> None:
        self._log("网络", msg)
        low = msg.lower()
        if "ready" in low:
            self._set_eth_badge(True)
        elif "closed" in low:
            self._set_eth_badge(False)
        self._refresh_dashboard()

    def _on_video_status(self, msg: str) -> None:
        self._log("视频", msg)
        low = msg.lower()
        if "started" in low:
            self.card_video_value.setText("运行中")
        elif "stopped" in low or "ended" in low:
            self.card_video_value.setText("空闲")

    def _on_error_status(self, msg: str) -> None:
        self._last_error = msg
        self._log("错误", msg)
        self._refresh_dashboard()

    def _note_tx(self, size: int) -> None:
        self._tx_packets += 1
        self._tx_bytes += max(0, size)
        self._refresh_dashboard()

    def _note_rx(self, size: int) -> None:
        self._rx_packets += 1
        self._rx_bytes += max(0, size)
        self._refresh_dashboard()

    def _refresh_dashboard(self) -> None:
        if not hasattr(self, "card_serial_value"):
            return
        self.card_serial_value.setText(self.serial_status_badge.text())
        self.card_eth_value.setText(self.eth_status_badge.text())
        self.card_flow_value.setText(f"发送 {self._tx_bytes / 1024:.1f} KB | 接收 {self._rx_bytes / 1024:.1f} KB")
        self.card_flow_value.setToolTip(
            f"发送包数: {self._tx_packets}\n接收包数: {self._rx_packets}\n最近错误: {self._last_error}"
        )

    def _update_clock(self) -> None:
        if not hasattr(self, "clock_label"):
            return
        self.clock_label.setText(dt.datetime.now().strftime("本地时间 %Y-%m-%d %H:%M:%S"))

    def _build_payload_from_text(self, text: str) -> bytes:
        if self.text_format_combo.currentData() == "hex":
            return parse_hex_string(text)
        return text.encode("utf-8")

    def _set_param_edit_value(self, algorithm: str, param: str, value: int | float) -> None:
        edit = self.param_value_map.get((algorithm, param))
        if edit is not None:
            edit.setText(str(value))

    def _calc_resize_dims(self, level: int) -> tuple[int, int]:
        level = max(0, min(255, int(level)))
        width = 1024 - (((1024 - 256) * level + 127) >> 8)
        height = 600 - (((600 - 150) * level + 127) >> 8)
        if width & 1:
            width -= 1
        if height & 1:
            height -= 1
        return width, height

    def _calc_zoom_in_dims(self, level: int) -> tuple[int, int, float]:
        level = max(0, min(255, int(level)))
        width = 1920 - (((1920 - 1024) * level + 127) >> 8)
        height = 1080 - (((1080 - 600) * level + 127) >> 8)
        if width & 1:
            width -= 1
        if height & 1:
            height -= 1
        zoom_factor = 1920.0 / max(1, width)
        return width, height, zoom_factor

    def _update_zoom_slider_label(self, value: int) -> None:
        value = max(-255, min(255, int(value)))
        if value < 0:
            level = abs(value)
            width, height = self._calc_resize_dims(level)
            self._set_chip_state(self.zoom_mode_chip, "缩小模式", "accent")
            self.zoom_value_label.setText(f"缩小 {level}")
            self.zoom_detail_label.setText(f"输出视口 {width} × {height}，周围保留黑边。")
            self._set_param_edit_value("resize", "scale", level)
            self._set_param_edit_value("zoom_in", "level", 0)
        elif value > 0:
            level = value
            width, height, zoom_factor = self._calc_zoom_in_dims(level)
            self._set_chip_state(self.zoom_mode_chip, "放大模式", "positive")
            self.zoom_value_label.setText(f"放大 {level}")
            self.zoom_detail_label.setText(f"裁切输入 {width} × {height}，等效倍率 {zoom_factor:.2f}x。")
            self._set_param_edit_value("resize", "scale", 0)
            self._set_param_edit_value("zoom_in", "level", level)
        else:
            self._set_chip_state(self.zoom_mode_chip, "原始视图", "neutral")
            self.zoom_value_label.setText("1024 × 600")
            self.zoom_detail_label.setText("输出与显示均保持原始视图，不启用缩放。")
            self._set_param_edit_value("resize", "scale", 0)
            self._set_param_edit_value("zoom_in", "level", 0)

    def _update_lowlight_slider_label(self, value: int) -> None:
        value = max(0, min(255, int(value)))
        if value == 0:
            self._set_chip_state(self.lowlight_state_chip, "关闭", "neutral")
            self.lowlight_value_label.setText("0")
        else:
            self._set_chip_state(self.lowlight_state_chip, "增强中", "accent")
            self.lowlight_value_label.setText(str(value))
        self._set_param_edit_value("lowlight", "gain", value)

    def _update_view_pad_label(self, pan_x: int, pan_y: int) -> None:
        self.view_pad_label.setText(f"x = {int(pan_x)}    y = {int(pan_y)}")
        self._set_param_edit_value("view", "pan_x", int(pan_x))
        self._set_param_edit_value("view", "pan_y", int(pan_y))

    def _set_zoom_slider_value_silent(self, value: int) -> None:
        was_blocked = self.zoom_slider.blockSignals(True)
        self.zoom_slider.setValue(value)
        self.zoom_slider.blockSignals(was_blocked)

    def _set_lowlight_slider_value_silent(self, value: int) -> None:
        was_blocked = self.lowlight_slider.blockSignals(True)
        self.lowlight_slider.setValue(value)
        self.lowlight_slider.blockSignals(was_blocked)

    def _on_zoom_slider_changed(self, value: int) -> None:
        self._update_zoom_slider_label(value)
        self.zoom_slider_timer.start(70)
        self._pulse_card(self.zoom_card)

    def _on_lowlight_slider_changed(self, value: int) -> None:
        self._update_lowlight_slider_label(value)
        self.lowlight_slider_timer.start(50)
        self._pulse_card(self.lowlight_card)

    def _on_view_pad_changed(self, pan_x: int, pan_y: int) -> None:
        self._update_view_pad_label(pan_x, pan_y)
        self._pulse_card(self.view_card)
        if not self._view_pad_programmatic:
            self.view_pad_timer.start(70)

    def _on_view_pad_animation_finished(self) -> None:
        if not self._view_pad_programmatic:
            return
        self._view_pad_programmatic = False
        self._flush_view_pad()

    def _send_fpga_serial_lines(self, lines: list[str], *, source: str) -> None:
        payload = "".join(f"{line}\n" for line in lines if line).encode("ascii")
        if not payload:
            return
        self.serial_worker.send_data(payload)
        self._note_tx(len(payload))
        self._log("算法", f"{source} -> {payload!r}")

    def _flush_zoom_slider(self) -> None:
        self.zoom_slider_timer.stop()
        value = int(self.zoom_slider.value())
        if value < 0:
            level = abs(value)
            self._send_fpga_serial_lines([f"X0", f"Z{level}"], source="缩小")
        elif value > 0:
            level = value
            self._send_fpga_serial_lines([f"Z0", f"X{level}"], source="放大")
        else:
            self._send_fpga_serial_lines(["Z0", "X0"], source="原始视图")

    def _flush_lowlight_slider(self) -> None:
        self.lowlight_slider_timer.stop()
        level = int(self.lowlight_slider.value())
        self._send_fpga_serial_lines([f"L{level}"], source="低照增强")

    def _flush_view_pad(self) -> None:
        self.view_pad_timer.stop()
        pan_x, pan_y = self.view_pad.value()
        self._send_fpga_serial_lines([f"H{int(pan_x)}", f"V{int(pan_y)}"], source="视野控制")

    def _reset_zoom_slider(self) -> None:
        self.zoom_slider_timer.stop()
        self._set_zoom_slider_value_silent(0)
        self._update_zoom_slider_label(0)
        self._pulse_card(self.zoom_card)
        self._flush_zoom_slider()

    def _reset_lowlight_slider(self) -> None:
        self.lowlight_slider_timer.stop()
        self._set_lowlight_slider_value_silent(0)
        self._update_lowlight_slider_label(0)
        self._pulse_card(self.lowlight_card)
        self._flush_lowlight_slider()

    def _reset_view_pad(self) -> None:
        self.view_pad_timer.stop()
        current_x, current_y = self.view_pad.value()
        if (current_x, current_y) == (128, 128):
            self._update_view_pad_label(128, 128)
            self._flush_view_pad()
            return
        self._view_pad_programmatic = True
        self.view_pad.animate_to_value(128, 128)

    def _build_fpga_serial_algo_command(self, algorithm: str, param: str, value: int | float | str) -> bytes | None:
        alg = algorithm.strip().lower()
        prm = param.strip().lower()

        try:
            numeric = float(value.strip()) if isinstance(value, str) else float(value)
        except Exception:
            return None

        if alg == "resize" and prm in {"scale", "level", "zoom"}:
            level = max(0, min(255, int(round(numeric))))
            return f"X0\nZ{level}\n".encode("ascii")

        if alg == "zoom_in" and prm in {"level", "scale", "zoom"}:
            level = max(0, min(255, int(round(numeric))))
            return f"Z0\nX{level}\n".encode("ascii")

        if alg == "view" and prm in {"pan_x", "x"}:
            pan_x = max(0, min(255, int(round(numeric))))
            return f"H{pan_x}\n".encode("ascii")

        if alg == "view" and prm in {"pan_y", "y"}:
            pan_y = max(0, min(255, int(round(numeric))))
            return f"V{pan_y}\n".encode("ascii")

        if alg == "lowlight" and prm in {"gain", "offset", "strength", "value"}:
            offset = max(0, min(255, int(round(numeric))))
            return f"L{offset}\n".encode("ascii")

        return None

    def _wrap_packet(self, pkt_type: int, payload: bytes) -> bytes:
        if self.packet_mode_combo.currentData() == "raw":
            return payload
        self._pkt_seq += 1
        return build_ccic_packet(pkt_type=pkt_type, seq=self._pkt_seq, payload=payload)

    def _send_serial_text(self) -> None:
        text = self.serial_tx_edit.text().strip()
        if not text:
            return
        try:
            payload = self._build_payload_from_text(text)
        except Exception as exc:
            self._warn(f"解析失败: {exc}")
            return
        data = self._wrap_packet(PacketType.COMMAND, payload)
        self.serial_worker.send_data(data)
        self._note_tx(len(data))
        self._log("串口发送", f"{len(data)} 字节")

    def _send_eth_text(self) -> None:
        text = self.eth_tx_edit.text().strip()
        if not text:
            return
        try:
            payload = self._build_payload_from_text(text)
        except Exception as exc:
            self._warn(f"解析失败: {exc}")
            return
        data = self._wrap_packet(PacketType.COMMAND, payload)
        self.eth_worker.send_data(data)
        self._note_tx(len(data))
        self._log("网络发送", f"{len(data)} 字节")

    def _on_serial_rx(self, data: bytes) -> None:
        self._serial_rx_buffer.extend(data)

        while True:
            newline_idx = self._serial_rx_buffer.find(b"\n")
            if newline_idx < 0:
                break

            raw_line = bytes(self._serial_rx_buffer[: newline_idx + 1])
            del self._serial_rx_buffer[: newline_idx + 1]

            try:
                ascii_text = raw_line.decode("ascii")
            except UnicodeDecodeError:
                ascii_text = ""

            if ascii_text and all((ch.isprintable() or ch in "\r\n\t") for ch in ascii_text):
                shown = ascii_text.replace("\r", "\\r").replace("\n", "\\n")
                line = f"[{dt.datetime.now():%H:%M:%S}] 接收 {len(raw_line)}B: {shown}"
            else:
                line = f"[{dt.datetime.now():%H:%M:%S}] 接收 {len(raw_line)}B: {to_hex_line(raw_line)}"
            self.serial_rx_text.append(line)

        self._note_rx(len(data))
        self._log("串口接收", f"{len(data)} 字节")

    def _on_eth_rx(self, data: bytes, ip: str, port: int) -> None:
        line = f"[{dt.datetime.now():%H:%M:%S}] 接收 {len(data)}B 来自 {ip}:{port}: {to_hex_line(data[:128])}"
        self.eth_rx_text.append(line)
        self._note_rx(len(data))
        self._log("网络接收", f"{len(data)} 字节 来自 {ip}:{port}")

    def _browse_image(self) -> None:
        path, _ = QFileDialog.getOpenFileName(
            self,
            "选择图片",
            "",
            "图片文件 (*.png *.jpg *.jpeg *.bmp *.tif *.tiff);;所有文件 (*.*)",
        )
        if path:
            self.image_path_edit.setText(path)

    def _send_image_file(self) -> None:
        path = Path(self.image_path_edit.text().strip())
        if not path.exists():
            self._warn("图片文件不存在。")
            return
        payload = path.read_bytes()
        chunks = chunk_frame_payload(
            frame_id=0,
            payload=payload,
            cfg=VideoChunkConfig(mtu_payload=int(self.image_chunk_spin.value())),
        )
        for chunk in chunks:
            pkt = self._wrap_packet(PacketType.IMAGE, chunk)
            self.eth_worker.send_data(pkt)
            self._note_tx(len(pkt))
        self._log("图片", f"图片已发送: {path.name}, 字节={len(payload)}, 分片数={len(chunks)}")
        QMessageBox.information(self, "发送图片", f"图片发送完成。\n{path.name}\n分片数: {len(chunks)}")

    def _start_video_stream(self) -> None:
        cfg = VideoStreamConfig(
            source=self.video_source_edit.text().strip(),
            fps=int(self.video_fps_spin.value()),
            jpeg_quality=int(self.video_quality_spin.value()),
            mtu_payload=int(self.video_chunk_spin.value()),
            width=int(self.video_w_spin.value()),
            height=int(self.video_h_spin.value()),
        )
        self.video_worker.start_stream(cfg)
        self.card_video_value.setText("启动中")

    def _stop_video_stream(self) -> None:
        self.video_worker.stop_stream()
        self.card_video_value.setText("空闲")

    def _on_video_packet(self, payload: bytes) -> None:
        pkt = self._wrap_packet(PacketType.VIDEO, payload)
        self.eth_worker.send_data(pkt)
        self._note_tx(len(pkt))

    def _on_video_stat(self, fps: int, frame_bytes: int) -> None:
        self.video_stat_label.setText(f"FPS: {fps} | 最近帧字节数: {frame_bytes}")
        self.card_video_value.setText(f"{fps} FPS")

    def _parse_numeric(self, text: str) -> int | float | str:
        stripped = text.strip()
        if stripped == "":
            return ""
        try:
            if "." in stripped or "e" in stripped.lower():
                return float(stripped)
            return int(stripped)
        except ValueError:
            return stripped

    def _sync_controls_from_algorithm(self, algorithm: str, param: str, value: int | float | str) -> None:
        alg = algorithm.strip().lower()
        prm = param.strip().lower()
        module_edit = self.module_value_map.get((alg, prm))
        if module_edit is not None:
            module_edit.setText(str(value))
        try:
            numeric = float(value.strip()) if isinstance(value, str) else float(value)
        except Exception:
            return

        if alg == "resize" and prm in {"scale", "level", "zoom"}:
            level = max(0, min(255, int(round(numeric))))
            self._set_zoom_slider_value_silent(-level if level != 0 else 0)
            self._update_zoom_slider_label(-level if level != 0 else 0)
            self._pulse_card(self.zoom_card)
            return

        if alg == "zoom_in" and prm in {"level", "scale", "zoom"}:
            level = max(0, min(255, int(round(numeric))))
            self._set_zoom_slider_value_silent(level)
            self._update_zoom_slider_label(level)
            self._pulse_card(self.zoom_card)
            return

        if alg == "lowlight" and prm in {"gain", "offset", "strength", "value"}:
            level = max(0, min(255, int(round(numeric))))
            self._set_lowlight_slider_value_silent(level)
            self._update_lowlight_slider_label(level)
            self._pulse_card(self.lowlight_card)
            return

        if alg == "view" and prm in {"pan_x", "x", "pan_y", "y"}:
            pan_x, pan_y = self.view_pad.value()
            if prm in {"pan_x", "x"}:
                pan_x = max(0, min(255, int(round(numeric))))
            else:
                pan_y = max(0, min(255, int(round(numeric))))
            self.view_pad.setValue(pan_x, pan_y, emit_signal=False)
            self._update_view_pad_label(pan_x, pan_y)
            self._pulse_card(self.view_card)

    def _dispatch_algo_param(
        self,
        algorithm: str,
        param: str,
        value: int | float | str,
        *,
        show_dialog: bool,
        source: str = "参数",
    ) -> None:
        if not algorithm or not param:
            self._warn("算法名和参数名不能为空。")
            return

        self._sync_controls_from_algorithm(algorithm, param, value)
        self._pulse_algorithm_card(algorithm)

        if self.algo_channel_combo.currentData() == "serial":
            fpga_cmd = self._build_fpga_serial_algo_command(algorithm, param, value)
            if fpga_cmd is not None:
                self.serial_worker.send_data(fpga_cmd)
                self._note_tx(len(fpga_cmd))
                self._log("算法", f"{source} 已发送 FPGA 串口命令 {fpga_cmd!r} 对应 {algorithm}.{param}={value}")
                self._pulse_card(self.advanced_card)
                if show_dialog:
                    QMessageBox.information(self, "参数发送", f"已发送: {algorithm}.{param} = {value}")
                return

        if self.algo_encode_combo.currentData() == "json":
            payload = build_algo_payload_json(algorithm, param, value)
        else:
            payload = build_algo_payload_csv(algorithm, param, value)
        pkt = self._wrap_packet(PacketType.ALGO, payload)

        if self.algo_channel_combo.currentData() == "serial":
            self.serial_worker.send_data(pkt)
        else:
            self.eth_worker.send_data(pkt)
        self._note_tx(len(pkt))
        self._pulse_card(self.advanced_card)
        self._log("算法", f"{source} 已发送 {algorithm}.{param}={value}，通道={self.algo_channel_combo.currentText()}")
        if show_dialog:
            QMessageBox.information(self, "参数发送", f"已发送: {algorithm}.{param} = {value}")

    def _send_algo_param(self, alg_edit: QLineEdit, param_edit: QLineEdit, value_edit: QLineEdit) -> None:
        algorithm = alg_edit.text().strip()
        param = param_edit.text().strip()
        value = self._parse_numeric(value_edit.text())
        self._dispatch_algo_param(algorithm, param, value, show_dialog=True, source="高级参数")

    def _start_sweep(self) -> None:
        start = float(self.sweep_start.value())
        end = float(self.sweep_end.value())
        step = float(self.sweep_step.value())
        if step == 0:
            self._warn("步进不能为 0。")
            return
        if (end - start) * step < 0:
            self._warn("步进方向无法到达结束值。")
            return

        values: list[float] = []
        current = start
        if step > 0:
            while current <= end + 1e-12:
                values.append(current)
                current += step
        else:
            while current >= end - 1e-12:
                values.append(current)
                current += step
        if not values:
            self._warn("扫描参数为空。")
            return

        self._sweep_values = values
        self._sweep_index = 0
        self.sweep_timer.start(int(self.sweep_interval.value()))
        self._set_chip_state(self.sweep_status, f"运行中（共 {len(values)} 点）", "accent")
        self._pulse_card(self.sweep_card)
        self._log("扫描", f"开始，共 {len(values)} 个点")

    def _stop_sweep(self) -> None:
        self.sweep_timer.stop()
        self._set_chip_state(self.sweep_status, "已停止", "warning")
        self._log("扫描", "已停止")

    def _on_sweep_tick(self) -> None:
        if self._sweep_index >= len(self._sweep_values):
            self.sweep_timer.stop()
            self._set_chip_state(self.sweep_status, "已完成", "positive")
            return

        algorithm = self.sweep_alg_combo.currentText().strip()
        param = self.sweep_param_edit.text().strip() or "value"
        value = self._sweep_values[self._sweep_index]
        self._dispatch_algo_param(algorithm, param, value, show_dialog=False, source="扫描")
        self._set_chip_state(
            self.sweep_status,
            f"{self._sweep_index + 1}/{len(self._sweep_values)} · {algorithm}.{param}={value}",
            "accent",
        )
        self._pulse_card(self.sweep_card)
        self._sweep_index += 1

    def _log(self, tag: str, msg: str) -> None:
        now = dt.datetime.now().strftime("%H:%M:%S")
        self.log_text.append(f"[{now}] [{tag}] {msg}")

    def _warn(self, msg: str) -> None:
        self._last_error = msg
        self._log("警告", msg)
        self._refresh_dashboard()
        QMessageBox.warning(self, "警告", msg)

    def closeEvent(self, event: QCloseEvent) -> None:
        self.video_worker.stop_stream()
        self.serial_worker.stop()
        self.eth_worker.stop()
        self.serial_worker.wait(1500)
        self.eth_worker.wait(1500)
        self.video_worker.wait(1500)
        super().closeEvent(event)

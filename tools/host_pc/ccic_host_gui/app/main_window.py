from __future__ import annotations

import datetime as dt
from pathlib import Path
from typing import Any

import serial.tools.list_ports
from PySide6.QtCore import QTimer, Qt
from PySide6.QtGui import QCloseEvent
from PySide6.QtWidgets import (
    QFileDialog,
    QFormLayout,
    QFrame,
    QGridLayout,
    QGroupBox,
    QHBoxLayout,
    QLabel,
    QLineEdit,
    QMainWindow,
    QMessageBox,
    QPushButton,
    QSpinBox,
    QDoubleSpinBox,
    QComboBox,
    QTabWidget,
    QTextEdit,
    QVBoxLayout,
    QWidget,
)

from .protocol import (
    PacketType,
    build_algo_payload_csv,
    build_algo_payload_json,
    build_ccic_packet,
    chunk_frame_payload,
    parse_hex_string,
    to_hex_line,
    VideoChunkConfig,
)
from .styles import APP_QSS
from .workers import EthernetWorker, SerialConfig, SerialWorker, UdpConfig, VideoStreamConfig, VideoStreamWorker


class MainWindow(QMainWindow):
    def __init__(self) -> None:
        super().__init__()
        self.setWindowTitle("CCIC FPGA 上位机控制台")
        self.resize(1440, 900)

        self._pkt_seq = 0
        self._sweep_values: list[float] = []
        self._sweep_index = 0
        self._tx_packets = 0
        self._rx_packets = 0
        self._tx_bytes = 0
        self._rx_bytes = 0
        self._last_error = "None"

        self.serial_worker = SerialWorker()
        self.eth_worker = EthernetWorker()
        self.video_worker = VideoStreamWorker()
        self.serial_worker.start()
        self.eth_worker.start()

        self._wire_workers()
        self._build_ui()
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

    def _build_ui(self) -> None:
        self.setStyleSheet(APP_QSS)

        root = QWidget()
        root_layout = QVBoxLayout(root)
        root_layout.setContentsMargins(14, 14, 14, 14)
        root_layout.setSpacing(10)

        banner = QFrame()
        banner.setObjectName("TopBanner")
        banner_layout = QHBoxLayout(banner)
        banner_layout.setContentsMargins(16, 10, 16, 10)
        title = QLabel("CCIC FPGA 上位机控制台")
        title.setObjectName("TitleLabel")
        subtitle = QLabel("串口 + 以太网 + 图像/视频传输 + 算法参数控制")
        subtitle.setObjectName("SubTitleLabel")
        contest_label = QLabel("中科亿海微杯 | 演示软件")
        contest_label.setObjectName("ContestLabel")
        self.clock_label = QLabel("")
        self.clock_label.setObjectName("ClockLabel")
        banner_text = QVBoxLayout()
        banner_text.addWidget(title)
        banner_text.addWidget(subtitle)
        banner_text.addWidget(contest_label)
        banner_text.addWidget(self.clock_label)
        banner_text.addStretch(1)
        banner_layout.addLayout(banner_text)

        banner_cards = QGridLayout()
        banner_cards.setHorizontalSpacing(8)
        banner_cards.setVerticalSpacing(8)
        serial_card, self.card_serial_value = self._build_status_card("串口", "离线")
        eth_card, self.card_eth_value = self._build_status_card("以太网", "离线")
        video_card, self.card_video_value = self._build_status_card("视频", "空闲")
        flow_card, self.card_flow_value = self._build_status_card("流量", "发送 0KB | 接收 0KB")
        banner_cards.addWidget(serial_card, 0, 0)
        banner_cards.addWidget(eth_card, 0, 1)
        banner_cards.addWidget(video_card, 1, 0)
        banner_cards.addWidget(flow_card, 1, 1)
        banner_layout.addLayout(banner_cards, 1)
        root_layout.addWidget(banner)

        body = QHBoxLayout()
        body.setSpacing(10)
        root_layout.addLayout(body, 1)

        left_panel = self._build_left_panel()
        body.addWidget(left_panel, 0)

        self.tabs = QTabWidget()
        self.tabs.addTab(self._build_serial_tab(), "串口控制台")
        self.tabs.addTab(self._build_eth_tab(), "以太网控制台")
        self.tabs.addTab(self._build_media_tab(), "图像 / 视频")
        self.tabs.addTab(self._build_algo_tab(), "算法控制")
        self.tabs.addTab(self._build_log_tab(), "系统日志")
        body.addWidget(self.tabs, 1)

        self.setCentralWidget(root)
        self._refresh_dashboard()
        self._update_clock()
        self.clock_timer = QTimer(self)
        self.clock_timer.timeout.connect(self._update_clock)
        self.clock_timer.start(1000)

    def _build_status_card(self, title: str, value: str) -> tuple[QFrame, QLabel]:
        card = QFrame()
        card.setObjectName("StatusCard")
        layout = QVBoxLayout(card)
        layout.setContentsMargins(10, 8, 10, 8)
        layout.setSpacing(4)
        t = QLabel(title)
        t.setObjectName("CardTitle")
        v = QLabel(value)
        v.setObjectName("CardValue")
        layout.addWidget(t)
        layout.addWidget(v)
        return card, v

    def _build_left_panel(self) -> QWidget:
        panel = QWidget()
        layout = QVBoxLayout(panel)
        layout.setSpacing(8)
        layout.setContentsMargins(0, 0, 0, 0)

        serial_box = QGroupBox("串口连接")
        s_form = QFormLayout(serial_box)
        self.serial_port_combo = QComboBox()
        self.serial_refresh_btn = QPushButton("刷新")
        self.serial_refresh_btn.clicked.connect(self._refresh_serial_ports)
        port_row = QWidget()
        port_row_layout = QHBoxLayout(port_row)
        port_row_layout.setContentsMargins(0, 0, 0, 0)
        port_row_layout.addWidget(self.serial_port_combo, 1)
        port_row_layout.addWidget(self.serial_refresh_btn)
        s_form.addRow("端口", port_row)

        self.serial_baud = QComboBox()
        self.serial_baud.addItems(["9600", "57600", "115200", "230400", "460800", "921600"])
        self.serial_baud.setCurrentText("115200")
        s_form.addRow("波特率", self.serial_baud)

        self.serial_status_badge = QLabel("离线")
        self.serial_status_badge.setObjectName("BadgeOffline")
        s_form.addRow("状态", self.serial_status_badge)

        s_btn_row = QWidget()
        s_btn_layout = QHBoxLayout(s_btn_row)
        s_btn_layout.setContentsMargins(0, 0, 0, 0)
        self.serial_open_btn = QPushButton("连接")
        self.serial_close_btn = QPushButton("断开")
        self.serial_close_btn.setObjectName("DangerButton")
        self.serial_open_btn.clicked.connect(self._open_serial)
        self.serial_close_btn.clicked.connect(self._close_serial)
        s_btn_layout.addWidget(self.serial_open_btn)
        s_btn_layout.addWidget(self.serial_close_btn)
        s_form.addRow("", s_btn_row)

        eth_box = QGroupBox("以太网连接 (UDP)")
        e_form = QFormLayout(eth_box)
        self.bind_ip_edit = QLineEdit("0.0.0.0")
        self.bind_port_spin = QSpinBox()
        self.bind_port_spin.setRange(1, 65535)
        self.bind_port_spin.setValue(5000)
        self.remote_ip_edit = QLineEdit("192.168.1.10")
        self.remote_port_spin = QSpinBox()
        self.remote_port_spin.setRange(1, 65535)
        self.remote_port_spin.setValue(6000)
        e_form.addRow("本地 IP", self.bind_ip_edit)
        e_form.addRow("本地端口", self.bind_port_spin)
        e_form.addRow("目标 IP", self.remote_ip_edit)
        e_form.addRow("目标端口", self.remote_port_spin)

        self.eth_status_badge = QLabel("离线")
        self.eth_status_badge.setObjectName("BadgeOffline")
        e_form.addRow("状态", self.eth_status_badge)

        e_btn_row = QWidget()
        e_btn_layout = QHBoxLayout(e_btn_row)
        e_btn_layout.setContentsMargins(0, 0, 0, 0)
        self.eth_open_btn = QPushButton("绑定 / 连接")
        self.eth_close_btn = QPushButton("关闭")
        self.eth_close_btn.setObjectName("DangerButton")
        self.eth_open_btn.clicked.connect(self._open_eth)
        self.eth_close_btn.clicked.connect(self._close_eth)
        e_btn_layout.addWidget(self.eth_open_btn)
        e_btn_layout.addWidget(self.eth_close_btn)
        e_form.addRow("", e_btn_row)

        packet_box = QGroupBox("封包模式")
        p_form = QFormLayout(packet_box)
        self.packet_mode_combo = QComboBox()
        self.packet_mode_combo.addItems(["原始数据", "CCICv1"])
        self.text_format_combo = QComboBox()
        self.text_format_combo.addItems(["ASCII 文本", "HEX"])
        p_form.addRow("发送模式", self.packet_mode_combo)
        p_form.addRow("文本格式", self.text_format_combo)

        layout.addWidget(serial_box)
        layout.addWidget(eth_box)
        layout.addWidget(packet_box)
        layout.addStretch(1)
        return panel

    def _build_serial_tab(self) -> QWidget:
        w = QWidget()
        v = QVBoxLayout(w)
        self.serial_rx_text = QTextEdit()
        self.serial_rx_text.setReadOnly(True)
        self.serial_rx_text.setPlaceholderText("串口接收数据...")
        v.addWidget(self.serial_rx_text, 1)

        tx_group = QGroupBox("串口发送")
        tx_layout = QHBoxLayout(tx_group)
        self.serial_tx_edit = QLineEdit()
        self.serial_tx_edit.setPlaceholderText("输入 ASCII 文本或 HEX 字节")
        self.serial_send_btn = QPushButton("发送")
        self.serial_send_btn.clicked.connect(self._send_serial_text)
        clear_btn = QPushButton("清空")
        clear_btn.clicked.connect(self.serial_rx_text.clear)
        tx_layout.addWidget(self.serial_tx_edit, 1)
        tx_layout.addWidget(self.serial_send_btn)
        tx_layout.addWidget(clear_btn)
        v.addWidget(tx_group)
        return w

    def _build_eth_tab(self) -> QWidget:
        w = QWidget()
        v = QVBoxLayout(w)
        self.eth_rx_text = QTextEdit()
        self.eth_rx_text.setReadOnly(True)
        self.eth_rx_text.setPlaceholderText("以太网接收数据...")
        v.addWidget(self.eth_rx_text, 1)

        tx_group = QGroupBox("以太网发送")
        tx_layout = QHBoxLayout(tx_group)
        self.eth_tx_edit = QLineEdit()
        self.eth_tx_edit.setPlaceholderText("输入 ASCII 文本或 HEX 字节")
        self.eth_send_btn = QPushButton("发送")
        self.eth_send_btn.clicked.connect(self._send_eth_text)
        clear_btn = QPushButton("清空")
        clear_btn.clicked.connect(self.eth_rx_text.clear)
        tx_layout.addWidget(self.eth_tx_edit, 1)
        tx_layout.addWidget(self.eth_send_btn)
        tx_layout.addWidget(clear_btn)
        v.addWidget(tx_group)
        return w

    def _build_media_tab(self) -> QWidget:
        w = QWidget()
        v = QVBoxLayout(w)

        img_box = QGroupBox("单张图片 -> FPGA")
        img_layout = QGridLayout(img_box)
        self.image_path_edit = QLineEdit()
        self.image_path_edit.setPlaceholderText("选择图片路径 (*.png, *.jpg, *.bmp)")
        browse_btn = QPushButton("浏览")
        browse_btn.clicked.connect(self._browse_image)
        send_img_btn = QPushButton("发送图片")
        send_img_btn.setObjectName("AccentButton")
        send_img_btn.clicked.connect(self._send_image_file)
        self.image_chunk_spin = QSpinBox()
        self.image_chunk_spin.setRange(256, 60000)
        self.image_chunk_spin.setValue(1200)
        img_layout.addWidget(QLabel("图片文件"), 0, 0)
        img_layout.addWidget(self.image_path_edit, 0, 1, 1, 2)
        img_layout.addWidget(browse_btn, 0, 3)
        img_layout.addWidget(QLabel("分片载荷"), 1, 0)
        img_layout.addWidget(self.image_chunk_spin, 1, 1)
        img_layout.addWidget(send_img_btn, 1, 3)
        v.addWidget(img_box)

        video_box = QGroupBox("实时视频流 -> FPGA")
        video_layout = QGridLayout(video_box)
        self.video_source_edit = QLineEdit("0")
        self.video_source_edit.setPlaceholderText("摄像头编号(0)或视频文件路径")
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
        self.video_stat_label = QLabel("FPS: 0 | 最近帧字节数: 0")

        start_btn = QPushButton("开始推流")
        start_btn.setObjectName("AccentButton")
        stop_btn = QPushButton("停止推流")
        stop_btn.setObjectName("DangerButton")
        start_btn.clicked.connect(self._start_video_stream)
        stop_btn.clicked.connect(self._stop_video_stream)

        video_layout.addWidget(QLabel("输入源"), 0, 0)
        video_layout.addWidget(self.video_source_edit, 0, 1, 1, 3)
        video_layout.addWidget(QLabel("帧率 FPS"), 1, 0)
        video_layout.addWidget(self.video_fps_spin, 1, 1)
        video_layout.addWidget(QLabel("JPEG 质量"), 1, 2)
        video_layout.addWidget(self.video_quality_spin, 1, 3)
        video_layout.addWidget(QLabel("分片载荷"), 2, 0)
        video_layout.addWidget(self.video_chunk_spin, 2, 1)
        video_layout.addWidget(QLabel("缩放宽度"), 2, 2)
        video_layout.addWidget(self.video_w_spin, 2, 3)
        video_layout.addWidget(QLabel("缩放高度"), 3, 2)
        video_layout.addWidget(self.video_h_spin, 3, 3)
        video_layout.addWidget(start_btn, 3, 0, 1, 1)
        video_layout.addWidget(stop_btn, 3, 1, 1, 1)
        video_layout.addWidget(self.video_stat_label, 4, 0, 1, 4)
        v.addWidget(video_box)

        v.addStretch(1)
        return w

    def _build_algo_tab(self) -> QWidget:
        w = QWidget()
        v = QVBoxLayout(w)

        param_box = QGroupBox("参数直接发送")
        param_layout = QGridLayout(param_box)
        self.algo_encode_combo = QComboBox()
        self.algo_encode_combo.addItems(["JSON", "CSV"])
        self.algo_channel_combo = QComboBox()
        self.algo_channel_combo.addItems(["以太网", "串口"])

        param_layout.addWidget(QLabel("编码"), 0, 0)
        param_layout.addWidget(self.algo_encode_combo, 0, 1)
        param_layout.addWidget(QLabel("通道"), 0, 2)
        param_layout.addWidget(self.algo_channel_combo, 0, 3)

        self.param_rows: list[tuple[str, QLineEdit, QLineEdit]] = []
        row_defs = [
            ("resize", "scale"),
            ("rotate", "angle_deg"),
            ("affine", "angle_deg"),
            ("lowlight", "gain"),
            ("hdr", "strength"),
            ("gamma", "gamma"),
            ("bilateral", "sigma"),
            ("guided", "eps"),
            ("digit_recognition", "threshold"),
        ]
        for i, (alg, param) in enumerate(row_defs, start=1):
            alg_edit = QLineEdit(alg)
            param_edit = QLineEdit(param)
            value_edit = QLineEdit()
            value_edit.setPlaceholderText("参数值")
            send_btn = QPushButton("发送")
            send_btn.clicked.connect(lambda _=False, a=alg_edit, p=param_edit, v=value_edit: self._send_algo_param(a, p, v))
            param_layout.addWidget(QLabel(f"#{i}"), i, 0)
            param_layout.addWidget(alg_edit, i, 1)
            param_layout.addWidget(param_edit, i, 2)
            param_layout.addWidget(value_edit, i, 3)
            param_layout.addWidget(send_btn, i, 4)
            self.param_rows.append((alg, param_edit, value_edit))
        v.addWidget(param_box)

        sweep_box = QGroupBox("连续参数扫描")
        sweep_layout = QGridLayout(sweep_box)
        self.sweep_alg_combo = QComboBox()
        self.sweep_alg_combo.addItems([a for a, _ in row_defs])
        self.sweep_param_edit = QLineEdit("value")
        self.sweep_start = QDoubleSpinBox()
        self.sweep_end = QDoubleSpinBox()
        self.sweep_step = QDoubleSpinBox()
        self.sweep_interval = QSpinBox()
        for d in (self.sweep_start, self.sweep_end, self.sweep_step):
            d.setDecimals(4)
            d.setRange(-100000.0, 100000.0)
        self.sweep_start.setValue(0.0)
        self.sweep_end.setValue(90.0)
        self.sweep_step.setValue(5.0)
        self.sweep_interval.setRange(10, 5000)
        self.sweep_interval.setValue(100)
        self.sweep_status = QLabel("空闲")

        sweep_start_btn = QPushButton("开始扫描")
        sweep_start_btn.setObjectName("AccentButton")
        sweep_stop_btn = QPushButton("停止扫描")
        sweep_stop_btn.setObjectName("DangerButton")
        sweep_start_btn.clicked.connect(self._start_sweep)
        sweep_stop_btn.clicked.connect(self._stop_sweep)

        sweep_layout.addWidget(QLabel("算法"), 0, 0)
        sweep_layout.addWidget(self.sweep_alg_combo, 0, 1)
        sweep_layout.addWidget(QLabel("参数名"), 0, 2)
        sweep_layout.addWidget(self.sweep_param_edit, 0, 3)
        sweep_layout.addWidget(QLabel("起始值"), 1, 0)
        sweep_layout.addWidget(self.sweep_start, 1, 1)
        sweep_layout.addWidget(QLabel("结束值"), 1, 2)
        sweep_layout.addWidget(self.sweep_end, 1, 3)
        sweep_layout.addWidget(QLabel("步进"), 2, 0)
        sweep_layout.addWidget(self.sweep_step, 2, 1)
        sweep_layout.addWidget(QLabel("间隔(ms)"), 2, 2)
        sweep_layout.addWidget(self.sweep_interval, 2, 3)
        sweep_layout.addWidget(sweep_start_btn, 3, 0, 1, 2)
        sweep_layout.addWidget(sweep_stop_btn, 3, 2, 1, 2)
        sweep_layout.addWidget(self.sweep_status, 4, 0, 1, 4)
        v.addWidget(sweep_box)

        self.sweep_timer = QTimer(self)
        self.sweep_timer.timeout.connect(self._on_sweep_tick)
        v.addStretch(1)
        return w

    def _build_log_tab(self) -> QWidget:
        w = QWidget()
        v = QVBoxLayout(w)
        self.log_text = QTextEdit()
        self.log_text.setReadOnly(True)
        clear_btn = QPushButton("清空日志")
        clear_btn.clicked.connect(self.log_text.clear)
        v.addWidget(self.log_text, 1)
        v.addWidget(clear_btn, 0, Qt.AlignRight)
        return w

    def _refresh_serial_ports(self) -> None:
        ports = [p.device for p in serial.tools.list_ports.comports()]
        self.serial_port_combo.clear()
        self.serial_port_combo.addItems(ports)
        if not ports:
            self.serial_port_combo.addItem("未发现串口")
        self._log("界面", f"串口列表已刷新: {ports if ports else '无'}")

    def _open_serial(self) -> None:
        port = self.serial_port_combo.currentText().strip()
        if not port or port == "未发现串口":
            self._warn("未选择有效串口。")
            return
        cfg = SerialConfig(port=port, baudrate=int(self.serial_baud.currentText()))
        self.serial_worker.open_port(cfg)

    def _close_serial(self) -> None:
        self.serial_worker.close_port()
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
        self.serial_status_badge.setText("在线" if online else "离线")
        self.serial_status_badge.setObjectName("BadgeOnline" if online else "BadgeOffline")
        self.serial_status_badge.style().unpolish(self.serial_status_badge)
        self.serial_status_badge.style().polish(self.serial_status_badge)

    def _set_eth_badge(self, online: bool) -> None:
        self.eth_status_badge.setText("在线" if online else "离线")
        self.eth_status_badge.setObjectName("BadgeOnline" if online else "BadgeOffline")
        self.eth_status_badge.style().unpolish(self.eth_status_badge)
        self.eth_status_badge.style().polish(self.eth_status_badge)

    def _on_serial_status(self, msg: str) -> None:
        self._log("串口", msg)
        low = msg.lower()
        if "connected" in low:
            self._set_serial_badge(True)
        elif "disconnected" in low or "close" in low:
            self._set_serial_badge(False)
        self._refresh_dashboard()

    def _on_eth_status(self, msg: str) -> None:
        self._log("以太网", msg)
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
        self.card_serial_value.setText(self.serial_status_badge.text().upper())
        self.card_eth_value.setText(self.eth_status_badge.text().upper())
        self.card_flow_value.setText(
            f"发送 {self._tx_bytes / 1024:.1f}KB | 接收 {self._rx_bytes / 1024:.1f}KB"
        )
        self.card_flow_value.setToolTip(
            f"发送包数: {self._tx_packets}\n接收包数: {self._rx_packets}\n最近错误: {self._last_error}"
        )

    def _update_clock(self) -> None:
        if not hasattr(self, "clock_label"):
            return
        self.clock_label.setText(dt.datetime.now().strftime("本地时间 %Y-%m-%d %H:%M:%S"))

    def _build_payload_from_text(self, text: str) -> bytes:
        if self.text_format_combo.currentText() == "HEX":
            return parse_hex_string(text)
        return text.encode("utf-8")

    def _wrap_packet(self, pkt_type: int, payload: bytes) -> bytes:
        if self.packet_mode_combo.currentText() == "原始数据":
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
        self._log("网口发送", f"{len(data)} 字节")

    def _on_serial_rx(self, data: bytes) -> None:
        line = f"[{dt.datetime.now():%H:%M:%S}] 接收 {len(data)}B: {to_hex_line(data)}"
        self.serial_rx_text.append(line)
        self._note_rx(len(data))
        self._log("串口接收", f"{len(data)} 字节")

    def _on_eth_rx(self, data: bytes, ip: str, port: int) -> None:
        line = f"[{dt.datetime.now():%H:%M:%S}] 接收 {len(data)}B 来自 {ip}:{port}: {to_hex_line(data[:128])}"
        self.eth_rx_text.append(line)
        self._note_rx(len(data))
        self._log("网口接收", f"{len(data)} 字节 来自 {ip}:{port}")

    def _browse_image(self) -> None:
        p, _ = QFileDialog.getOpenFileName(
            self,
            "选择图片",
            "",
            "图片文件 (*.png *.jpg *.jpeg *.bmp *.tif *.tiff);;所有文件 (*.*)",
        )
        if p:
            self.image_path_edit.setText(p)

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
        QMessageBox.information(self, "发送图片", f"图片发送完成。\n{path.name}\n分片数={len(chunks)}")

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
        s = text.strip()
        if s == "":
            return ""
        try:
            if "." in s or "e" in s.lower():
                return float(s)
            return int(s)
        except ValueError:
            return s

    def _send_algo_param(self, alg_edit: QLineEdit, param_edit: QLineEdit, value_edit: QLineEdit) -> None:
        algorithm = alg_edit.text().strip()
        param = param_edit.text().strip()
        value = self._parse_numeric(value_edit.text())
        if not algorithm or not param:
            self._warn("算法名和参数名不能为空。")
            return

        if self.algo_encode_combo.currentText() == "JSON":
            payload = build_algo_payload_json(algorithm, param, value)
        else:
            payload = build_algo_payload_csv(algorithm, param, value)
        pkt = self._wrap_packet(PacketType.ALGO, payload)

        channel = self.algo_channel_combo.currentText()
        if channel == "串口":
            self.serial_worker.send_data(pkt)
        else:
            self.eth_worker.send_data(pkt)
        self._note_tx(len(pkt))
        self._log("算法", f"已发送 {algorithm}.{param}={value}，通道={channel}")
        QMessageBox.information(self, "参数发送", f"已发送: {algorithm}.{param} = {value}")

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
        v = start
        if step > 0:
            while v <= end + 1e-12:
                values.append(v)
                v += step
        else:
            while v >= end - 1e-12:
                values.append(v)
                v += step
        if not values:
            self._warn("扫描参数为空。")
            return

        self._sweep_values = values
        self._sweep_index = 0
        self.sweep_timer.start(int(self.sweep_interval.value()))
        self.sweep_status.setText(f"运行中（共 {len(values)} 个点）")
        self._log("扫描", f"开始: {len(values)} 个点")

    def _stop_sweep(self) -> None:
        self.sweep_timer.stop()
        self.sweep_status.setText("已停止")
        self._log("扫描", "已停止")

    def _on_sweep_tick(self) -> None:
        if self._sweep_index >= len(self._sweep_values):
            self._stop_sweep()
            self.sweep_status.setText("已完成")
            return

        algorithm = self.sweep_alg_combo.currentText().strip()
        param = self.sweep_param_edit.text().strip() or "value"
        value = self._sweep_values[self._sweep_index]
        if self.algo_encode_combo.currentText() == "JSON":
            payload = build_algo_payload_json(algorithm, param, value)
        else:
            payload = build_algo_payload_csv(algorithm, param, value)
        pkt = self._wrap_packet(PacketType.ALGO, payload)
        if self.algo_channel_combo.currentText() == "串口":
            self.serial_worker.send_data(pkt)
        else:
            self.eth_worker.send_data(pkt)
        self._note_tx(len(pkt))
        self.sweep_status.setText(
            f"运行中 {self._sweep_index + 1}/{len(self._sweep_values)}: {algorithm}.{param}={value}"
        )
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

#!/usr/bin/env python3
"""Redshift Store — Graphical Askpass Dialog for Sudo.

Provides a clean, fast Material You dialog for single-sign-on administrator
authentication during package management operations.
"""

from __future__ import annotations

import os
import sys


def main() -> int:
    # Support headless test override
    test_pwd = os.environ.get("REDSHIFT_TEST_PASSWORD")
    if test_pwd is not None:
        sys.stdout.write(test_pwd + "\n")
        return 0

    prompt = sys.argv[1] if len(sys.argv) > 1 else "Digite sua senha de administrador:"

    # 1. Try native PyQt6 Material You dialog
    try:
        from PyQt6.QtCore import Qt
        from PyQt6.QtGui import QFont
        from PyQt6.QtWidgets import (
            QApplication,
            QDialog,
            QHBoxLayout,
            QLabel,
            QLineEdit,
            QPushButton,
            QVBoxLayout,
        )

        app = QApplication(["redshift-askpass"])
        app.setApplicationName("Redshift Store")

        dialog = QDialog()
        dialog.setWindowTitle("Redshift Store — Autenticação")
        dialog.setFixedSize(400, 170)
        dialog.setWindowFlags(
            Qt.WindowType.Dialog
            | Qt.WindowType.WindowStaysOnTopHint
            | Qt.WindowType.CustomizeWindowHint
            | Qt.WindowType.WindowTitleHint
            | Qt.WindowType.WindowCloseButtonHint
        )

        dialog.setStyleSheet("""
            QDialog {
                background-color: #141318;
                color: #e6e1e9;
                font-family: 'Google Sans Flex', 'sans-serif';
            }
            QLabel#title {
                color: #e6e1e9;
                font-size: 13px;
                font-weight: bold;
            }
            QLabel#subtitle {
                color: #c9c5d0;
                font-size: 11px;
            }
            QLineEdit {
                background-color: #201f25;
                color: #e6e1e9;
                border: 1px solid #48454e;
                border-radius: 8px;
                padding: 6px 10px;
                font-size: 13px;
                selection-background-color: #473f77;
            }
            QLineEdit:focus {
                border: 1.5px solid #c9bfff;
            }
            QPushButton {
                border-radius: 8px;
                padding: 6px 16px;
                font-size: 11px;
                font-weight: 500;
            }
            QPushButton#btnCancel {
                background-color: #2b292f;
                color: #c9c5d0;
                border: 1px solid #48454e;
            }
            QPushButton#btnCancel:hover {
                background-color: #36343a;
            }
            QPushButton#btnOk {
                background-color: #c9bfff;
                color: #30285f;
                border: none;
                font-weight: bold;
            }
            QPushButton#btnOk:hover {
                background-color: #dcd4ff;
            }
        """)

        layout = QVBoxLayout(dialog)
        layout.setContentsMargins(24, 20, 24, 20)
        layout.setSpacing(10)

        title_lbl = QLabel("Autenticação de Administrador", dialog)
        title_lbl.setObjectName("title")
        layout.addWidget(title_lbl)

        sub_lbl = QLabel(
            "Digite sua senha para autorizar a operação de pacotes:",
            dialog,
        )
        sub_lbl.setObjectName("subtitle")
        layout.addWidget(sub_lbl)

        pwd_input = QLineEdit(dialog)
        pwd_input.setEchoMode(QLineEdit.EchoMode.Password)
        pwd_input.setPlaceholderText("Senha de administrador")
        layout.addWidget(pwd_input)

        btn_box = QHBoxLayout()
        btn_box.setSpacing(10)
        btn_box.addStretch()

        btn_cancel = QPushButton("Cancelar", dialog)
        btn_cancel.setObjectName("btnCancel")
        btn_cancel.clicked.connect(dialog.reject)
        btn_box.addWidget(btn_cancel)

        btn_ok = QPushButton("Autenticar", dialog)
        btn_ok.setObjectName("btnOk")
        btn_ok.setDefault(True)
        btn_ok.clicked.connect(dialog.accept)
        btn_box.addWidget(btn_ok)

        layout.addLayout(btn_box)

        pwd_input.setFocus()
        if dialog.exec() == QDialog.DialogCode.Accepted:
            pwd = pwd_input.text()
            if pwd:
                sys.stdout.write(pwd + "\n")
                return 0
        return 1

    except Exception:
        pass

    # 2. Fallback via Zenity if PyQt6 GUI fails
    try:
        import subprocess

        res = subprocess.run(
            [
                "/usr/bin/zenity",
                "--password",
                "--title=Redshift Store — Autenticação de Administrador",
            ],
            capture_output=True,
            text=True,
            check=False,
        )
        if res.returncode == 0 and res.stdout:
            sys.stdout.write(res.stdout.strip() + "\n")
            return 0
    except Exception:
        pass

    return 1


if __name__ == "__main__":
    sys.exit(main())

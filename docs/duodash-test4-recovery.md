# test4 recovery after device report

User reports test3 does not hide the bar or fill the screen and breaks divider ratio dragging. The adapter hooks CNABDividerView touch lifecycle methods directly. The exact runtime cause is not confirmed; do not claim working fullscreen or drag based on packaging checks.

Immediate recovery: upgrade the existing com.chuong.duodash-fullscreen-complete package to 1.1.3+adapter1~test4, preserving every one of the 44 source payload files byte-for-byte and their modes, including original Settings, app picker, split engine and existing source helper. Original postinst/prerm are unchanged. No DuoDashFullscreenAdapter files are shipped. dpkg upgrade removes the old adapter payload; respring restarts affected processes.

The new fullscreen/bar adapter is withdrawn from the Sileo package. New fullscreen controls must not intercept the divider touch sequence. No Simulator or physical device runtime pass is claimed. Source baseline metadata is unchanged.

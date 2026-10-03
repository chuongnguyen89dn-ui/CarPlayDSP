# DuoDash test3: restore original Settings payload

Restores both PreferenceLoader registration and native bundle Root.plist byte-for-byte from the pinned source DEB. Removes test2's controller-registration rewrite. All 42 original files outside the replaced fullscreen helper are required to match their source bytes and permissions; original postinst/prerm remain unchanged. UI, app picker, and split binaries are untouched.

Package: com.chuong.duodash-fullscreen-complete
Version: 1.1.3+adapter1~test3
Source SHA256: ea0d3bb8c8b9da2b45c3f158f390a7966419e84899f820d06f45cd51401fa465

Local packaging verification passed. This does not establish device installation, Settings runtime, CarPlay behavior, or Simulator success. Source DEB baseline remains byte-identical and its metadata is unchanged.

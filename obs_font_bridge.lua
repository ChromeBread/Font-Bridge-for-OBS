--[[
================================================================================
 Font Bridge for OBS  -  OBS Studio Lua script (Windows)

 Adds a "Text (Bridge)" source that renders through Windows GDI instead of
 GDI+, so fonts that OBS's built-in text source cannot read correctly
 (CFF-based OpenType .otf, fonts temporarily activated with font managers,
 etc.) display properly.

 The property page is borrowed at runtime from OBS's own "Text (GDI+)" source,
 so the editing UI always matches the running OBS version.

 Author : ChromeBread feat. BlackDream
================================================================================
]]

local obs = obslua
local ffi = require("ffi")
local bit = require("bit")

--------------------------------------------------------------------------------
-- Meta
--------------------------------------------------------------------------------
local SCRIPT_NAME = "Font Bridge for OBS"
local SOURCE_ID   = "fontbridge_text"
local VERSION     = "1.3.0"
local BUILD_DATE  = { year = 2026, month = 11, day = 1 }
local AUTHOR      = "ChromeBread feat. BlackDream"
local DOCK_HTML   = "obs_font_bridge_dock.html"
local DOCK_DATA   = "obs_font_bridge_dock_data"
local PREFS_FILE  = "obs_font_bridge_prefs.json"
local GDIPLUS_IDS = { "text_gdiplus_v3", "text_gdiplus_v2", "text_gdiplus" }

--------------------------------------------------------------------------------
-- Localization
--------------------------------------------------------------------------------
local LANGS = { "en", "ja", "ko", "id", "fr", "zh_TW" }
local LANG_NAMES = {
	en = "English", ja = "日本語", ko = "한국어",
	id = "Bahasa Indonesia", fr = "Français", zh_TW = "繁體中文",
}

local I18N = {
	en = {
		ws_host = "WebSocket host", ws_port = "WebSocket port", ws_password = "WebSocket password",
		uninstall_info = "<b>Uninstall</b><br>1. Export your settings below if you want to keep them.<br>2. Tools → Scripts: select this script and press −.<br>3. Run Safe_Uninstaller.bat from the folder below. To remove files by hand, delete only these and leave the folder itself:<br><br>%s<br>%s",
		backup_export_file = "Export settings to", backup_export = "Export settings",
		backup_import_file = "Import settings from", backup_import = "Import settings",
		backup_no_file = "Choose a file first.", backup_failed = "The file could not be read or written.",
		backup_wrong_app = "This file belongs to a different script.",
		backup_exported = "Settings exported.", backup_imported = "Settings imported. Hotkeys apply after restarting OBS.",
		source_name    = "Text (Bridge)",
		desc           = "<p>A text source that renders through Windows GDI, so fonts that OBS's built-in text source can't read &mdash; such as CFF-based OpenType (.otf) fonts or fonts temporarily activated with font managers &mdash; display correctly.</p><p>Add it from <b>Sources &rarr; + &rarr; Text (Bridge)</b>. Its settings are the same as Text (GDI+), and changes apply in real time.</p>",
		desc_simple    = "<p>A script that lets OBS Studio (Windows) naturally load the fonts it couldn't display before.</p><p>Add it from <b>Sources &rarr; + &rarr; Text (Bridge)</b>.</p>",
		version        = "Version",
		build_date     = "Build date",
		author         = "Author",
		language       = "Language",
		lang_auto      = "Auto (OBS)",
		lang_note      = "Reload the script (⟳) to apply the language to the description and the source name.",
		debug_on       = "Debug Mode ✅",
		debug_off      = "Debug Mode ⬜",
		dock_url       = "Dock URL",
		dock_howto     = "1. Copy the Dock URL.\n2. In OBS: Docks → Custom Browser Docks… → enter a name and paste the URL.\n3. The dock talks to OBS via WebSocket (Tools → WebSocket Server Settings). Enter the same port / password below.",
		regen_previews = "Regenerate font previews",
		font_missing   = "⚠ The font \"%s\" was not found (it may have been deactivated in your font manager). A fallback font is used.",
	},
	ja = {
		ws_host = "WebSocket ホスト", ws_port = "WebSocket ポート", ws_password = "WebSocket パスワード",
		uninstall_info = "<b>アンインストール</b><br>1. 設定を残す場合は、下の項目で書き出します。<br>2. ツール → スクリプト でこのスクリプトを選び、− を押します。<br>3. 下のフォルダにある Safe_Uninstaller.bat を実行します。手動で消す場合は次のファイルだけを削除し、フォルダ自体は消さないでください。<br><br>%s<br>%s",
		backup_export_file = "設定の書き出し先", backup_export = "設定を書き出す",
		backup_import_file = "設定の読み込み元", backup_import = "設定を読み込む",
		backup_no_file = "先にファイルを選んでください。", backup_failed = "ファイルを読み書きできませんでした。",
		backup_wrong_app = "別のスクリプトのファイルです。",
		backup_exported = "設定を書き出しました。", backup_imported = "設定を読み込みました。ホットキーはOBSの再起動後に反映されます。",
		source_name    = "テキスト (Bridge)",
		desc           = "<p>Windows GDI でテキストを描画するソースです。OBS標準のテキストソースでは正しく読めないフォント（CFF形式の OpenType (.otf) や、フォント管理ソフトで一時的に有効化したフォント）も正しく表示できます。</p><p><b>ソース → ＋ → テキスト (Bridge)</b> から追加してください。設定項目はテキスト (GDI+) と同じで、変更はリアルタイムで反映されます。</p>",
		desc_simple    = "<p>OBSで反映できなかったフォントを自然の力で正しく読み込めるようにするスクリプトです。</p><p><b>ソース → ＋ → テキスト (Bridge)</b> から追加してください。</p>",
		version        = "バージョン",
		build_date     = "ビルド日",
		author         = "製作者",
		language       = "言語",
		lang_auto      = "自動 (OBS)",
		lang_note      = "説明文とソース名への言語反映は、スクリプトの再読み込み (⟳) 後に行われます。",
		debug_on       = "デバッグモード ✅",
		debug_off      = "デバッグモード ⬜",
		dock_url       = "ドックURL",
		dock_howto     = "1. ドックURLをコピーします。\n2. OBSの「ドック → カスタムブラウザドック…」で名前を入力し、URLを貼り付けます。\n3. ドックは WebSocket（ツール → WebSocketサーバー設定）でOBSと通信します。同じポートとパスワードを下の欄に入力します。",
		regen_previews = "フォントプレビューを再生成",
		font_missing   = "⚠ フォント「%s」が見つかりません（フォント管理ソフトで無効化された可能性があります）。代替フォントで表示しています。",
	},
	ko = {
		ws_host = "WebSocket 호스트", ws_port = "WebSocket 포트", ws_password = "WebSocket 비밀번호",
		uninstall_info = "<b>제거</b><br>1. 설정을 유지하려면 아래 항목에서 내보내세요.<br>2. 도구 → 스크립트에서 이 스크립트를 선택하고 − 를 누르세요.<br>3. 아래 폴더의 Safe_Uninstaller.bat을 실행하세요. 직접 지울 때는 다음 파일만 삭제하고 폴더 자체는 지우지 마세요.<br><br>%s<br>%s",
		backup_export_file = "설정 내보내기 위치", backup_export = "설정 내보내기",
		backup_import_file = "설정 가져오기 파일", backup_import = "설정 가져오기",
		backup_no_file = "먼저 파일을 선택하세요.", backup_failed = "파일을 읽거나 쓸 수 없습니다.",
		backup_wrong_app = "다른 스크립트의 파일입니다.",
		backup_exported = "설정을 내보냈습니다.", backup_imported = "설정을 가져왔습니다. 단축키는 OBS를 다시 시작하면 적용됩니다.",
		source_name    = "텍스트 (Bridge)",
		desc           = "<p>Windows GDI로 텍스트를 렌더링하는 소스입니다. OBS 기본 텍스트 소스로는 제대로 읽을 수 없는 글꼴(CFF 기반 OpenType(.otf) 글꼴이나 글꼴 관리 프로그램으로 임시 활성화한 글꼴)도 올바르게 표시합니다.</p><p><b>소스 → + → 텍스트 (Bridge)</b>에서 추가하세요. 설정 항목은 텍스트 (GDI+)와 같으며 변경 사항이 실시간으로 반영됩니다.</p>",
		desc_simple    = "<p>OBS에서 표시하지 못했던 글꼴을 자연스럽게 올바로 불러올 수 있게 해 주는 스크립트입니다.</p><p><b>소스 → + → 텍스트 (Bridge)</b>에서 추가하세요.</p>",
		version        = "버전",
		build_date     = "빌드 날짜",
		author         = "제작자",
		language       = "언어",
		lang_auto      = "자동 (OBS)",
		lang_note      = "설명과 소스 이름에 언어를 적용하려면 스크립트를 다시 불러오세요 (⟳).",
		debug_on       = "디버그 모드 ✅",
		debug_off      = "디버그 모드 ⬜",
		dock_url       = "도크 URL",
		dock_howto     = "1. 도크 URL을 복사합니다.\n2. OBS에서 도크 → 사용자 지정 브라우저 도크… 에 이름을 입력하고 URL을 붙여넣습니다.\n3. 도크는 WebSocket(도구 → WebSocket 서버 설정)으로 OBS와 통신합니다. 같은 포트와 비밀번호를 아래 칸에 입력하세요.",
		regen_previews = "글꼴 미리보기 다시 생성",
		font_missing   = "⚠ 글꼴 \"%s\"을(를) 찾을 수 없습니다(글꼴 관리 프로그램에서 비활성화되었을 수 있습니다). 대체 글꼴로 표시합니다.",
	},
	id = {
		ws_host = "Host WebSocket", ws_port = "Port WebSocket", ws_password = "Kata sandi WebSocket",
		uninstall_info = "<b>Hapus instalasi</b><br>1. Ekspor pengaturan di bawah jika ingin menyimpannya.<br>2. Alat → Skrip: pilih skrip ini lalu tekan −.<br>3. Jalankan Safe_Uninstaller.bat dari folder di bawah. Untuk menghapus manual, hapus hanya file berikut dan jangan hapus foldernya:<br><br>%s<br>%s",
		backup_export_file = "Ekspor pengaturan ke", backup_export = "Ekspor pengaturan",
		backup_import_file = "Impor pengaturan dari", backup_import = "Impor pengaturan",
		backup_no_file = "Pilih file terlebih dahulu.", backup_failed = "File tidak dapat dibaca atau ditulis.",
		backup_wrong_app = "File ini milik skrip lain.",
		backup_exported = "Pengaturan diekspor.", backup_imported = "Pengaturan diimpor. Hotkey berlaku setelah OBS dimulai ulang.",
		source_name    = "Teks (Bridge)",
		desc           = "<p>Sumber teks yang dirender melalui Windows GDI, sehingga font yang tidak dapat dibaca oleh sumber teks bawaan OBS &mdash; seperti font OpenType berbasis CFF (.otf) atau font yang diaktifkan sementara dengan pengelola font &mdash; dapat ditampilkan dengan benar.</p><p>Tambahkan dari <b>Sumber &rarr; + &rarr; Teks (Bridge)</b>. Pengaturannya sama dengan Teks (GDI+), dan perubahan diterapkan secara real-time.</p>",
		desc_simple    = "<p>Skrip yang membuat OBS dapat memuat secara alami font yang sebelumnya tidak bisa ditampilkan.</p><p>Tambahkan dari <b>Sumber &rarr; + &rarr; Teks (Bridge)</b>.</p>",
		version        = "Versi",
		build_date     = "Tanggal build",
		author         = "Pembuat",
		language       = "Bahasa",
		lang_auto      = "Otomatis (OBS)",
		lang_note      = "Muat ulang skrip (⟳) untuk menerapkan bahasa pada deskripsi dan nama sumber.",
		debug_on       = "Mode Debug ✅",
		debug_off      = "Mode Debug ⬜",
		dock_url       = "URL Dock",
		dock_howto     = "1. Salin URL Dock.\n2. Di OBS: Dock → Dock Peramban Kustom… → masukkan nama dan tempel URL.\n3. Dock berkomunikasi dengan OBS melalui WebSocket (Alat → Pengaturan Server WebSocket). Masukkan port / kata sandi yang sama di bawah.",
		regen_previews = "Buat ulang pratinjau font",
		font_missing   = "⚠ Font \"%s\" tidak ditemukan (mungkin telah dinonaktifkan di pengelola font). Font pengganti digunakan.",
	},
	fr = {
		ws_host = "Hôte WebSocket", ws_port = "Port WebSocket", ws_password = "Mot de passe WebSocket",
		uninstall_info = "<b>Désinstallation</b><br>1. Exportez vos réglages ci-dessous si vous voulez les garder.<br>2. Outils → Scripts : sélectionnez ce script et cliquez sur −.<br>3. Lancez Safe_Uninstaller.bat depuis le dossier ci-dessous. Pour supprimer à la main, effacez uniquement ces fichiers, sans toucher au dossier :<br><br>%s<br>%s",
		backup_export_file = "Exporter les réglages vers", backup_export = "Exporter les réglages",
		backup_import_file = "Importer les réglages depuis", backup_import = "Importer les réglages",
		backup_no_file = "Choisissez d'abord un fichier.", backup_failed = "Impossible de lire ou d'écrire le fichier.",
		backup_wrong_app = "Ce fichier appartient à un autre script.",
		backup_exported = "Réglages exportés.", backup_imported = "Réglages importés. Les raccourcis s'appliquent après le redémarrage d'OBS.",
		source_name    = "Texte (Bridge)",
		desc           = "<p>Une source de texte rendue via Windows GDI, afin que les polices que la source de texte intégrée d'OBS ne lit pas correctement &mdash; comme les polices OpenType basées sur CFF (.otf) ou les polices activées temporairement avec un gestionnaire de polices &mdash; s'affichent correctement.</p><p>Ajoutez-la via <b>Sources &rarr; + &rarr; Texte (Bridge)</b>. Ses paramètres sont identiques à ceux de Texte (GDI+) et les changements s'appliquent en temps réel.</p>",
		desc_simple    = "<p>Un script qui permet à OBS de charger naturellement les polices qu'il ne pouvait pas afficher.</p><p>Ajoutez-la via <b>Sources &rarr; + &rarr; Texte (Bridge)</b>.</p>",
		version        = "Version",
		build_date     = "Date de build",
		author         = "Auteur",
		language       = "Langue",
		lang_auto      = "Automatique (OBS)",
		lang_note      = "Rechargez le script (⟳) pour appliquer la langue à la description et au nom de la source.",
		debug_on       = "Mode débogage ✅",
		debug_off      = "Mode débogage ⬜",
		dock_url       = "URL du dock",
		dock_howto     = "1. Copiez l'URL du dock.\n2. Dans OBS : Docks → Docks de navigateur personnalisés… → saisissez un nom et collez l'URL.\n3. Le dock communique avec OBS via WebSocket (Outils → Paramètres du serveur WebSocket). Saisissez le même port / mot de passe ci-dessous.",
		regen_previews = "Régénérer les aperçus de police",
		font_missing   = "⚠ La police « %s » est introuvable (elle a peut-être été désactivée dans votre gestionnaire de polices). Une police de remplacement est utilisée.",
	},
	zh_TW = {
		ws_host = "WebSocket 主機", ws_port = "WebSocket 連接埠", ws_password = "WebSocket 密碼",
		uninstall_info = "<b>解除安裝</b><br>1. 若要保留設定，請先在下方匯出。<br>2. 在 工具 → 腳本 中選取此腳本並按 −。<br>3. 執行下方資料夾中的 Safe_Uninstaller.bat。若要手動刪除，請只刪除下列檔案，不要刪除資料夾本身。<br><br>%s<br>%s",
		backup_export_file = "設定匯出至", backup_export = "匯出設定",
		backup_import_file = "設定匯入來源", backup_import = "匯入設定",
		backup_no_file = "請先選擇檔案。", backup_failed = "無法讀取或寫入檔案。",
		backup_wrong_app = "此檔案屬於其他腳本。",
		backup_exported = "已匯出設定。", backup_imported = "已匯入設定。快速鍵會在重新啟動 OBS 後套用。",
		source_name    = "文字 (Bridge)",
		desc           = "<p>透過 Windows GDI 繪製文字的來源。即使是 OBS 內建文字來源無法正確讀取的字型（例如 CFF 格式的 OpenType (.otf) 字型，或以字型管理工具暫時啟用的字型），也能正確顯示。</p><p>請從 <b>來源 → ＋ → 文字 (Bridge)</b> 新增。設定項目與 文字 (GDI+) 相同，變更會即時套用。</p>",
		desc_simple    = "<p>讓 OBS 能自然地正確讀取原本無法顯示的字型的腳本。</p><p>請從 <b>來源 → ＋ → 文字 (Bridge)</b> 新增。</p>",
		version        = "版本",
		build_date     = "建置日期",
		author         = "製作者",
		language       = "語言",
		lang_auto      = "自動 (OBS)",
		lang_note      = "重新載入腳本 (⟳) 後，說明文字與來源名稱才會套用新語言。",
		debug_on       = "偵錯模式 ✅",
		debug_off      = "偵錯模式 ⬜",
		dock_url       = "Dock 網址",
		dock_howto     = "1. 複製 Dock 網址。\n2. 在 OBS 中：停駐視窗 → 自訂瀏覽器停駐視窗… → 輸入名稱並貼上網址。\n3. Dock 透過 WebSocket（工具 → WebSocket 伺服器設定）與 OBS 通訊，請在下方輸入相同的連接埠與密碼。",
		regen_previews = "重新產生字型預覽",
		font_missing   = "⚠ 找不到字型「%s」（可能已在字型管理工具中停用），目前以替代字型顯示。",
	},
}

local MONTHS = {
	en = { "January", "February", "March", "April", "May", "June", "July",
	       "August", "September", "October", "November", "December" },
	fr = { "janvier", "février", "mars", "avril", "mai", "juin", "juillet",
	       "août", "septembre", "octobre", "novembre", "décembre" },
	id = { "Januari", "Februari", "Maret", "April", "Mei", "Juni", "Juli",
	       "Agustus", "September", "Oktober", "November", "Desember" },
}

local function format_date(d, lang)
	if lang == "ja" or lang == "zh_TW" then
		return string.format("%d年%d月%d日", d.year, d.month, d.day)
	elseif lang == "ko" then
		return string.format("%d년 %d월 %d일", d.year, d.month, d.day)
	elseif lang == "fr" then
		return (d.day == 1 and "1er" or tostring(d.day)) .. " " .. MONTHS.fr[d.month] .. " " .. d.year
	elseif lang == "id" then
		return d.day .. " " .. MONTHS.id[d.month] .. " " .. d.year
	end
	return MONTHS.en[d.month] .. " " .. d.day .. ", " .. d.year
end

-- Any OBS locale outside the six supported languages falls back to English.
local function map_locale(loc)
	loc = (loc or ""):gsub("_", "-"):lower()
	if loc:find("^ja") then return "ja" end
	if loc:find("^ko") then return "ko" end
	if loc:find("^id") then return "id" end
	if loc:find("^fr") then return "fr" end
	if loc == "zh-tw" or loc == "zh-hk" or loc:find("^zh%-hant") then return "zh_TW" end
	return "en"
end

local function detect_obs_lang()
	local ok, loc = pcall(function() return obs.obs_get_locale() end)
	return map_locale(ok and loc or "en")
end

local lang_setting = "auto" -- "auto" or one of LANGS
local current_lang = "en"

local function T(key)
	local t = I18N[current_lang] or I18N.en
	return t[key] or I18N.en[key] or key
end

local function resolve_lang()
	current_lang = (lang_setting ~= "auto" and I18N[lang_setting]) and lang_setting or detect_obs_lang()
end

--------------------------------------------------------------------------------
-- Win32 / libobs FFI
--------------------------------------------------------------------------------
ffi.cdef [[
typedef void *HANDLE;
typedef void *HDC;
typedef void *HFONT;
typedef void *HBITMAP;
typedef void *HGDIOBJ;
typedef int BOOL;
typedef uint32_t DWORD;
typedef uint32_t UINT;
typedef int32_t LONG;
typedef intptr_t LPARAM;
typedef uint16_t WCHAR;

typedef struct { LONG left, top, right, bottom; } RECT;
typedef struct { LONG cx, cy; } SIZE;
typedef struct { DWORD lo, hi; } FILETIME;
typedef struct {
	DWORD dwFileAttributes; FILETIME ftCreationTime; FILETIME ftLastAccessTime;
	FILETIME ftLastWriteTime; DWORD nFileSizeHigh; DWORD nFileSizeLow;
} WIN32_FILE_ATTRIBUTE_DATA;
typedef struct {
	DWORD biSize; LONG biWidth; LONG biHeight; uint16_t biPlanes; uint16_t biBitCount;
	DWORD biCompression; DWORD biSizeImage; LONG biXPelsPerMeter; LONG biYPelsPerMeter;
	DWORD biClrUsed; DWORD biClrImportant;
} BITMAPINFOHEADER;
typedef struct { BITMAPINFOHEADER bmiHeader; DWORD bmiColors[1]; } BITMAPINFO;
typedef struct {
	LONG lfHeight, lfWidth, lfEscapement, lfOrientation, lfWeight;
	uint8_t lfItalic, lfUnderline, lfStrikeOut, lfCharSet, lfOutPrecision,
	        lfClipPrecision, lfQuality, lfPitchAndFamily;
	WCHAR lfFaceName[32];
} LOGFONTW;
typedef int (__stdcall *FONTENUMPROCW)(const LOGFONTW *, const void *, DWORD, LPARAM);

HDC     CreateCompatibleDC(HDC);
BOOL    DeleteDC(HDC);
HBITMAP CreateDIBSection(HDC, const BITMAPINFO *, UINT, void **, HANDLE, DWORD);
HGDIOBJ SelectObject(HDC, HGDIOBJ);
BOOL    DeleteObject(HGDIOBJ);
HFONT   CreateFontW(int, int, int, int, int, DWORD, DWORD, DWORD, DWORD, DWORD,
                    DWORD, DWORD, DWORD, const WCHAR *);
int     SetBkMode(HDC, int);
DWORD   SetTextColor(HDC, DWORD);
int     GetTextFaceW(HDC, int, WCHAR *);
DWORD   GetFontData(HDC, DWORD, DWORD, void *, DWORD);
int     DrawTextW(HDC, const WCHAR *, int, RECT *, UINT);
BOOL    TextOutW(HDC, int, int, const WCHAR *, int);
BOOL    GetTextExtentPoint32W(HDC, const WCHAR *, int, SIZE *);
BOOL    GdiFlush(void);
int     EnumFontFamiliesExW(HDC, LOGFONTW *, FONTENUMPROCW, LPARAM, DWORD);
DWORD   CharUpperBuffW(WCHAR *, DWORD);
DWORD   CharLowerBuffW(WCHAR *, DWORD);

int     MultiByteToWideChar(UINT, DWORD, const char *, int, WCHAR *, int);
int     WideCharToMultiByte(UINT, DWORD, const WCHAR *, int, char *, int, const char *, BOOL *);
HANDLE  CreateFileW(const WCHAR *, DWORD, DWORD, void *, DWORD, DWORD, HANDLE);
BOOL    WriteFile(HANDLE, const void *, DWORD, DWORD *, void *);
BOOL    ReadFile(HANDLE, void *, DWORD, DWORD *, void *);
DWORD   GetFileSize(HANDLE, DWORD *);
BOOL    CloseHandle(HANDLE);
DWORD   GetFileAttributesW(const WCHAR *);
BOOL    GetFileAttributesExW(const WCHAR *, int, WIN32_FILE_ATTRIBUTE_DATA *);
BOOL    CreateDirectoryW(const WCHAR *, void *);
BOOL    RemoveDirectoryW(const WCHAR *);
BOOL    DeleteFileW(const WCHAR *);
typedef struct {
	DWORD dwFileAttributes; FILETIME ftCreationTime; FILETIME ftLastAccessTime; FILETIME ftLastWriteTime;
	DWORD nFileSizeHigh; DWORD nFileSizeLow; DWORD dwReserved0; DWORD dwReserved1;
	WCHAR cFileName[260]; WCHAR cAlternateFileName[14];
} WIN32_FIND_DATAW;
HANDLE  FindFirstFileW(const WCHAR *, WIN32_FIND_DATAW *);
BOOL    FindNextFileW(HANDLE, WIN32_FIND_DATAW *);
BOOL    FindClose(HANDLE);

typedef struct gs_texture gs_texture_t;
typedef struct gs_effect gs_effect_t;
typedef struct gs_effect_param gs_eparam_t;
gs_texture_t *gs_texture_create(uint32_t, uint32_t, int, uint32_t, const uint8_t **, uint32_t);
void          gs_texture_destroy(gs_texture_t *);
gs_effect_t  *obs_get_base_effect(int);
gs_eparam_t  *gs_effect_get_param_by_name(const gs_effect_t *, const char *);
void          gs_effect_set_texture(gs_eparam_t *, gs_texture_t *);
bool          gs_effect_loop(gs_effect_t *, const char *);
void          gs_draw_sprite(gs_texture_t *, uint32_t, uint32_t, uint32_t);
void          obs_enter_graphics(void);
void          obs_leave_graphics(void);
]]

local C = ffi.C -- kernel32 / user32 / gdi32 are reachable through ffi.C on Windows
local libobs = ffi.load("obs")

local GS_BGRA            = obs.GS_BGRA or 5
local OBS_EFFECT_DEFAULT = obs.OBS_EFFECT_DEFAULT or 0

local CP_UTF8 = 65001
local DT_LEFT, DT_CENTER, DT_RIGHT = 0x0, 0x1, 0x2
local DT_VCENTER, DT_WORDBREAK, DT_SINGLELINE, DT_EXPANDTABS = 0x4, 0x10, 0x20, 0x40
local DT_NOCLIP, DT_CALCRECT, DT_NOPREFIX = 0x100, 0x400, 0x800
local ALIGN_FLAGS = { left = DT_LEFT, center = DT_CENTER, right = DT_RIGHT }
local DEFAULT_CHARSET, SYMBOL_CHARSET = 1, 2
local NONANTIALIASED_QUALITY, ANTIALIASED_QUALITY = 3, 4
local TRANSPARENT = 1
local RASTER_FONTTYPE = 1
local OBS_FONT_BOLD, OBS_FONT_ITALIC, OBS_FONT_UNDERLINE, OBS_FONT_STRIKEOUT = 1, 2, 4, 8
local MAX_DIM = 8192
local FONT_RECHECK = 3 -- seconds between font rescans while a source's font is missing

local function utf8_to_wide(s)
	local n = C.MultiByteToWideChar(CP_UTF8, 0, s, #s, nil, 0)
	local buf = ffi.new("WCHAR[?]", n + 1)
	if n > 0 then C.MultiByteToWideChar(CP_UTF8, 0, s, #s, buf, n) end
	buf[n] = 0
	return buf, n
end

local function wide_to_utf8(w, n)
	n = n or -1
	local len = C.WideCharToMultiByte(CP_UTF8, 0, w, n, nil, 0, nil, nil)
	if len <= 0 then return "" end
	local buf = ffi.new("char[?]", len)
	C.WideCharToMultiByte(CP_UTF8, 0, w, n, buf, len, nil, nil)
	if n == -1 then len = len - 1 end
	return ffi.string(buf, len)
end

local function wpath(path)
	return (utf8_to_wide((path:gsub("/", "\\"))))
end

local function file_exists(path)
	return C.GetFileAttributesW(wpath(path)) ~= 0xFFFFFFFF
end

local function file_mtime(path)
	local fa = ffi.new("WIN32_FILE_ATTRIBUTE_DATA")
	if C.GetFileAttributesExW(wpath(path), 0, fa) == 0 then return nil end
	return fa.ftLastWriteTime.hi * 4294967296 + fa.ftLastWriteTime.lo
end

local function ensure_dir(path)
	C.CreateDirectoryW(wpath(path), nil)
end

local function write_file(path, data, len)
	local h = C.CreateFileW(wpath(path), 0x40000000 --[[GENERIC_WRITE]], 1 --[[FILE_SHARE_READ]],
		nil, 2 --[[CREATE_ALWAYS]], 0x80, nil)
	if ffi.cast("intptr_t", h) == -1 then return false end
	if type(data) == "string" then len = #data end -- passed as is: a cast would not keep it alive
	local written = ffi.new("DWORD[1]")
	local ok = C.WriteFile(h, data, len, written, nil) ~= 0
	C.CloseHandle(h)
	return ok
end

-- Reads a text file as UTF-8 (UTF-16LE with BOM is converted), like Text (GDI+).
local function read_text_file(path)
	if path == "" then return "" end
	local h = C.CreateFileW(wpath(path), 0x80000000 --[[GENERIC_READ]], 3 --[[SHARE_READ|WRITE]],
		nil, 3 --[[OPEN_EXISTING]], 0x80, nil)
	if ffi.cast("intptr_t", h) == -1 then return "" end
	local size = C.GetFileSize(h, nil)
	if size == 0xFFFFFFFF or size == 0 then C.CloseHandle(h); return "" end
	local buf = ffi.new("uint8_t[?]", size + 2)
	local got = ffi.new("DWORD[1]")
	C.ReadFile(h, buf, size, got, nil)
	C.CloseHandle(h)
	local n = got[0]
	if n >= 2 and buf[0] == 0xFF and buf[1] == 0xFE then
		return wide_to_utf8(ffi.cast("const WCHAR *", buf + 2), math.floor((n - 2) / 2))
	end
	if n >= 3 and buf[0] == 0xEF and buf[1] == 0xBB and buf[2] == 0xBF then
		return ffi.string(buf + 3, n - 3)
	end
	return ffi.string(buf, n)
end

local function log(level, msg)
	obs.script_log(level, msg)
end

--------------------------------------------------------------------------------
-- Font enumeration (GDI sees fonts activated by font managers at runtime)
--------------------------------------------------------------------------------
local font_list    = nil -- sorted array of GDI face names
local font_set     = {}  -- face -> true
local font_vert    = {}  -- "@face" -> true (vertical variants)
local font_weight  = {}  -- face -> weight of its first enumerated style
local font_charset = {}  -- face -> charset to request
local font_sig     = ""
local font_epoch   = 0   -- bumped when the font table changes so sources re-render
local last_enum    = -1e9

local function enumerate_fonts()
	local hdc = C.CreateCompatibleDC(nil)
	local lf = ffi.new("LOGFONTW")
	lf.lfCharSet = DEFAULT_CHARSET
	local list, set, vert, weight, charset = {}, {}, {}, {}, {}
	local cb = ffi.cast("FONTENUMPROCW", function(plf, _, ftype, _)
		if bit.band(ftype, RASTER_FONTTYPE) == 0 then
			local name = wide_to_utf8(plf.lfFaceName)
			if name:sub(1, 1) == "@" then
				vert[name] = true
			elseif name ~= "" then
				if not set[name] then
					set[name] = true
					list[#list + 1] = name
					weight[name] = plf.lfWeight
					charset[name] = plf.lfCharSet == SYMBOL_CHARSET and SYMBOL_CHARSET or DEFAULT_CHARSET
				elseif plf.lfCharSet ~= SYMBOL_CHARSET then
					charset[name] = DEFAULT_CHARSET
				end
			end
		end
		return 1
	end)
	C.EnumFontFamiliesExW(hdc, lf, cb, 0, 0)
	cb:free()
	C.DeleteDC(hdc)
	table.sort(list, function(a, b)
		local la, lb = a:lower(), b:lower()
		if la == lb then return a < b end
		return la < lb
	end)
	font_list, font_set, font_vert, font_weight, font_charset = list, set, vert, weight, charset
	last_enum = os.clock()
	local sig = table.concat(list, "\0")
	if sig ~= font_sig then
		font_sig = sig
		font_epoch = font_epoch + 1
	end
	return list
end
jit.off(enumerate_fonts) -- FFI callbacks must not be invoked from JIT-compiled code

local function ensure_fonts()
	if not font_list then enumerate_fonts() end
	return font_list
end

--------------------------------------------------------------------------------
-- GDI rendering
--------------------------------------------------------------------------------
local function make_font(face, height, weight, italic, underline, strike, quality, escapement)
	return C.CreateFontW(height, 0, escapement or 0, escapement or 0, weight,
		italic and 1 or 0, underline and 1 or 0, strike and 1 or 0,
		font_charset[face] or DEFAULT_CHARSET, 0, 0, quality or ANTIALIASED_QUALITY, 0,
		(utf8_to_wide(face)))
end

--------------------------------------------------------------------------------
-- Font name table ('name'): maps every family / full / PostScript name of a font,
-- in every language, to the GDI face that loads it.
--------------------------------------------------------------------------------
local NAME_TAG  = 0x656D616E -- 'name' as a little-endian DWORD
local GDI_ERROR = 0xFFFFFFFF
local FAMILY_IDS = { 1, 4, 6, 16, 21 } -- family, full, PostScript, typographic family, WWS family
local STYLE_IDS  = { 2, 17, 22 }       -- subfamily, typographic subfamily, WWS subfamily
local PLAIN_STYLES = { [""] = true, regular = true, normal = true, bold = true,
	italic = true, ["bold italic"] = true, oblique = true }

local function u16be(b, o) return b[o] * 256 + b[o + 1] end

-- Returns { [nameID] = { string, ... } } from the Windows (UTF-16BE) records, all languages.
local function parse_name_table(b, size)
	local out = {}
	if size < 6 then return out end
	local count, base = u16be(b, 2), u16be(b, 4)
	for r = 0, count - 1 do
		local o = 6 + r * 12
		if o + 12 > size then break end
		local pid, eid, nid = u16be(b, o), u16be(b, o + 2), u16be(b, o + 6)
		local len, off = u16be(b, o + 8), base + u16be(b, o + 10)
		if pid == 3 and (eid == 1 or eid == 10) and len >= 2 and off + len <= size then
			local n = math.floor(len / 2)
			local w = ffi.new("WCHAR[?]", n)
			for i = 0, n - 1 do w[i] = u16be(b, off + i * 2) end
			local s = wide_to_utf8(w, n)
			if s ~= "" then
				out[nid] = out[nid] or {}
				table.insert(out[nid], s)
			end
		end
	end
	return out
end

do -- self-check: one record, nameID 4 = "Ab"
	local t = { 0,0, 0,1, 0,18, 0,3, 0,1, 4,9, 0,4, 0,4, 0,0, 0,0x41, 0,0x62 }
	local r = parse_name_table(ffi.new("uint8_t[?]", #t, t), #t)
	assert(r[4] and r[4][1] == "Ab", "name table parser self-check failed")
end

local name_index, name_epoch = nil, -1 -- name -> { { face = gdi_face, styles = set }, ... }

local function build_name_index()
	local t0, idx = os.clock(), {}
	local hdc = C.CreateCompatibleDC(nil)
	for _, face in ipairs(font_list) do
		local hfont = make_font(face, -16, font_weight[face] or 400, false, false, false)
		local old = C.SelectObject(hdc, hfont)
		local size = C.GetFontData(hdc, NAME_TAG, 0, nil, 0)
		if size ~= GDI_ERROR and size > 6 then
			local buf = ffi.new("uint8_t[?]", size)
			if C.GetFontData(hdc, NAME_TAG, 0, buf, size) == size then
				local names = parse_name_table(buf, size)
				local entry = { face = face, styles = {} }
				for _, id in ipairs(STYLE_IDS) do
					for _, s in ipairs(names[id] or {}) do entry.styles[s:lower()] = true end
				end
				for _, id in ipairs(FAMILY_IDS) do
					for _, s in ipairs(names[id] or {}) do
						idx[s] = idx[s] or {}
						table.insert(idx[s], entry)
					end
				end
			end
		end
		C.SelectObject(hdc, old)
		C.DeleteObject(hfont)
	end
	C.DeleteDC(hdc)
	name_index, name_epoch = idx, font_epoch
	log(obs.LOG_INFO, string.format("font name index: %d faces in %.0f ms", #font_list, (os.clock() - t0) * 1000))
end

-- OBS's font dialog may report a typographic family plus a style, e.g.
-- "Example Std" + "B", while GDI only knows "Example Std B".
-- Returns the GDI faces that may be meant, best first.
local function face_candidates(face, style)
	local st = style:lower()
	if PLAIN_STYLES[st] and font_set[face] then return { face } end
	if not name_index or name_epoch ~= font_epoch then build_name_index() end

	local out, seen = {}, {}
	local function add(n)
		if n and font_set[n] and not seen[n] then seen[n] = true; out[#out + 1] = n end
	end
	local entries = name_index[face] or {}
	for _, e in ipairs(entries) do if e.styles[st] then add(e.face) end end -- family + style
	for _, e in ipairs(name_index[face .. " " .. style] or {}) do add(e.face) end -- full name
	add(face)
	for _, e in ipairs(entries) do add(e.face) end -- full / PostScript name, or style not found
	return out
end

local function text_face(hdc)
	local buf = ffi.new("WCHAR[64]")
	C.GetTextFaceW(hdc, 64, buf)
	return wide_to_utf8(buf)
end

-- Selects the best matching GDI font into hdc. Returns hfont, old_font, face, found.
local function select_font(hdc, cfg, height, quality, vertical)
	ensure_fonts()
	local cands = face_candidates(cfg.face, cfg.style)
	if #cands == 0 and os.clock() - last_enum > 2 then
		enumerate_fonts() -- the font may have just been activated in the font manager
		cands = face_candidates(cfg.face, cfg.style)
	end
	local found = #cands > 0
	if not found then cands = { cfg.face } end

	local function create(face)
		local fw = (face ~= cfg.face and font_weight[face]) or 400
		local name = (vertical and font_vert["@" .. face]) and "@" .. face or face
		return make_font(name, height, cfg.bold and math.max(700, fw) or fw, cfg.italic,
			cfg.underline, cfg.strikeout, quality, vertical and 2700 or 0), name
	end
	for i, face in ipairs(cands) do
		local hfont, name = create(face)
		local old = C.SelectObject(hdc, hfont)
		local actual = text_face(hdc)
		if debug_mode then -- font names are never logged (privacy)
			log(obs.LOG_INFO, string.format("[debug] font candidate %d/%d: %s", i, #cands,
				actual:lower() == name:lower() and "match" or "no match"))
		end
		if actual:lower() == name:lower() then return hfont, old, face, found end
		C.SelectObject(hdc, old)
		C.DeleteObject(hfont)
	end
	-- GDI may report a localized name even for a real match: trust the first candidate
	local hfont = create(cands[1])
	return hfont, C.SelectObject(hdc, hfont), cands[1], found
end

local function new_dib(hdc, w, h)
	local bmi = ffi.new("BITMAPINFO")
	local hd = bmi.bmiHeader
	hd.biSize = ffi.sizeof("BITMAPINFOHEADER")
	hd.biWidth, hd.biHeight = w, -h -- top-down
	hd.biPlanes, hd.biBitCount = 1, 32
	local pbits = ffi.new("void *[1]")
	local hbm = C.CreateDIBSection(hdc, bmi, 0, pbits, nil, 0)
	if hbm == nil or pbits[0] == nil then return nil end
	return hbm, ffi.cast("uint8_t *", pbits[0])
end

-- Box-filter a white-on-black 32bpp DIB (supersampled by s) into an 8-bit mask.
local function downsample(bits, sw, s, w, h)
	local m = ffi.new("uint8_t[?]", w * h)
	if s == 1 then
		for i = 0, w * h - 1 do m[i] = bits[i * 4 + 1] end
		return m
	end
	local inv = 1 / (s * s)
	for y = 0, h - 1 do
		for x = 0, w - 1 do
			local sum = 0
			for yy = 0, s - 1 do
				local row = ((y * s + yy) * sw + x * s) * 4 + 1
				for xx = 0, s - 1 do sum = sum + bits[row + xx * 4] end
			end
			m[y * w + x] = sum * inv + 0.5
		end
	end
	return m
end

-- Offsets for a disc of radius r; coarser steps for large radii keep draw counts low.
local function disc_steps(r)
	local step = math.max(1, math.floor(r / 8))
	local v, out = -r, {}
	while v < r do out[#out + 1] = v; v = v + step end
	out[#out + 1] = r
	return out
end

local function rgb(c)
	return bit.band(c, 0xFF), bit.band(bit.rshift(c, 8), 0xFF), bit.band(bit.rshift(c, 16), 0xFF)
end

local function is_space(ch) return ch == 32 or ch == 9 or ch == 10 or ch == 13 or ch == 0x3000 end

local function apply_transform(w, n, mode)
	if mode == 1 then
		C.CharUpperBuffW(w, n)
	elseif mode == 2 then
		C.CharLowerBuffW(w, n)
	elseif mode == 3 then
		C.CharLowerBuffW(w, n)
		for i = 0, n - 1 do
			if i == 0 or is_space(w[i - 1]) then C.CharUpperBuffW(w + i, 1) end
		end
	end
end

local function last_lines(text, n)
	local lines = {}
	for line in (text .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = line end
	if lines[#lines] == "" then lines[#lines] = nil end
	if #lines <= n then return table.concat(lines, "\n") end
	return table.concat(lines, "\n", #lines - n + 1)
end

-- Returns width, height, BGRA pixel buffer (non-premultiplied), font_missing.
local function render_text(cfg)
	local text = cfg.text:gsub("\r\n", "\n")
	if cfg.chatlog then text = last_lines(text, math.max(1, cfg.chatlog_lines)) end
	if text == "" and not cfg.extents then return 0, 0, nil, false end

	local wtext, wlen = utf8_to_wide(text)
	apply_transform(wtext, wlen, cfg.transform)

	local s = cfg.antialiasing and 2 or 1
	local quality = cfg.antialiasing and ANTIALIASED_QUALITY or NONANTIALIASED_QUALITY
	-- GDI+ strokes the outline centred on the glyph edge, so it grows by half the width.
	local orad = cfg.outline and math.max(1, math.floor(cfg.outline_size / 2 + 0.5)) or 0
	local hdc = C.CreateCompatibleDC(nil)
	local hfont, old_font, face, found, W, H, draw

	while true do
		hfont, old_font, face, found = select_font(hdc, cfg, cfg.size * s, quality, cfg.vertical)
		local pad = orad + (cfg.extents and 0 or math.ceil(cfg.size * (cfg.italic and 0.2 or 0.05)))
		local ps = pad * s

		if cfg.vertical then
			-- shortcut: vertical text ignores word wrap, add it if extents + vertical is needed
			local lines, colw, maxlen = {}, 0, 0
			local start = 0
			for i = 0, wlen do
				if i == wlen or wtext[i] == 10 then
					local sz = ffi.new("SIZE")
					C.GetTextExtentPoint32W(hdc, wtext + start, i - start, sz)
					lines[#lines + 1] = { off = start, len = i - start, cx = sz.cx }
					colw = math.max(colw, sz.cy)
					maxlen = math.max(maxlen, sz.cx)
					start = i + 1
				end
			end
			local bw, bh = #lines * colw, maxlen
			if cfg.extents then
				W, H = cfg.extents_cx, cfg.extents_cy
			else
				W, H = math.ceil(bw / s) + pad * 2, math.ceil(bh / s) + pad * 2
			end
			local iw, ih = W * s - ps * 2, H * s - ps * 2
			local right = ps + iw -- columns start at the right edge, like Japanese vertical text
			draw = function(dx, dy)
				-- each glyph cell of a 270° font extends left of the reference point
				for i, ln in ipairs(lines) do
					local y = ps
					if cfg.align == "center" then y = ps + (ih - ln.cx) / 2
					elseif cfg.align == "right" then y = ps + ih - ln.cx end
					C.TextOutW(hdc, right - (i - 1) * colw + dx, y + dy, wtext + ln.off, ln.len)
				end
			end
		else
			local flags = bit.bor(DT_NOPREFIX, DT_EXPANDTABS, DT_NOCLIP, ALIGN_FLAGS[cfg.align] or DT_LEFT)
			local rc = ffi.new("RECT")
			if cfg.extents and cfg.extents_wrap then
				flags = bit.bor(flags, DT_WORDBREAK)
				rc.right = math.max(1, cfg.extents_cx * s - ps * 2)
			end
			C.DrawTextW(hdc, wtext, wlen, rc, bit.bor(flags, DT_CALCRECT))
			local tw, th = rc.right - rc.left, rc.bottom - rc.top
			if cfg.extents then
				W, H = cfg.extents_cx, cfg.extents_cy
			else
				W, H = math.ceil(tw / s) + pad * 2, math.ceil(th / s) + pad * 2
			end
			local iw, ih = W * s - ps * 2, H * s - ps * 2
			local bw = cfg.extents and iw or tw
			local by = ps + (cfg.extents and (cfg.valign == "center" and (ih - th) / 2
				or cfg.valign == "bottom" and (ih - th) or 0) or 0)
			draw = function(dx, dy)
				rc.left, rc.top = ps + dx, by + dy
				rc.right, rc.bottom = ps + dx + bw, by + dy + th
				C.DrawTextW(hdc, wtext, wlen, rc, flags)
			end
		end

		W, H = math.max(1, W), math.max(1, H)
		if s == 1 or (W * s <= MAX_DIM and H * s <= MAX_DIM) then break end
		C.SelectObject(hdc, old_font)
		C.DeleteObject(hfont)
		s = 1
	end
	W, H = math.min(W, MAX_DIM), math.min(H, MAX_DIM)
	local sw, sh = W * s, H * s

	local function cleanup(...)
		C.SelectObject(hdc, old_font)
		C.DeleteObject(hfont)
		C.DeleteDC(hdc)
		return ...
	end

	local tbm, tbits = new_dib(hdc, sw, sh)
	if not tbm then return cleanup(0, 0, nil, not found) end
	local old_bm = C.SelectObject(hdc, tbm)
	C.SetBkMode(hdc, TRANSPARENT)
	C.SetTextColor(hdc, 0xFFFFFF)
	draw(0, 0)

	local obm, obits
	if orad > 0 then
		obm, obits = new_dib(hdc, sw, sh)
		if obm then
			C.SelectObject(hdc, obm)
			local r = orad * s
			local steps = disc_steps(r)
			local lim = r * r + r
			for _, dy in ipairs(steps) do
				for _, dx in ipairs(steps) do
					if dx * dx + dy * dy <= lim then draw(dx, dy) end
				end
			end
		end
	end
	C.GdiFlush()

	local tmask = downsample(tbits, sw, s, W, H)
	local omask = obits and downsample(obits, sw, s, W, H)
	C.SelectObject(hdc, old_bm)
	C.DeleteObject(tbm)
	if obm then C.DeleteObject(obm) end

	-- composite: background, then outline, then (gradient) text
	local tr, tg, tb = rgb(cfg.color)
	local gr, gg, gb = rgb(cfg.gradient_color)
	local or_, og, ob = rgb(cfg.outline_color)
	local br, bg, bb = rgb(cfg.bk_color)
	local kt = cfg.opacity / 100 / 255
	local kg = cfg.gradient_opacity / 100 / 255
	local ko = cfg.outline_opacity / 100 / 255
	local ab = cfg.bk_opacity / 100
	local grad = cfg.gradient
	local gc, gs = math.cos(math.rad(cfg.gradient_dir)), math.sin(math.rad(cfg.gradient_dir))
	local p0 = math.min(0, (W - 1) * gc) + math.min(0, (H - 1) * gs)
	local p1 = math.max(0, (W - 1) * gc) + math.max(0, (H - 1) * gs)
	local ginv = p1 > p0 and 1 / (p1 - p0) or 0

	local out = ffi.new("uint8_t[?]", W * H * 4)
	for y = 0, H - 1 do
		for x = 0, W - 1 do
			local i = y * W + x
			local pa = ab
			local pr, pg, pb = br * ab, bg * ab, bb * ab
			if omask then
				local a = omask[i] * ko
				local na = 1 - a
				pr, pg, pb, pa = or_ * a + pr * na, og * a + pg * na, ob * a + pb * na, a + pa * na
			end
			local m = tmask[i]
			if m > 0 then
				local cr, cg, cb, a = tr, tg, tb, m * kt
				if grad then
					local t = (x * gc + y * gs - p0) * ginv
					local u = 1 - t
					cr, cg, cb = tr * u + gr * t, tg * u + gg * t, tb * u + gb * t
					a = m * (kt * u + kg * t)
				end
				local na = 1 - a
				pr, pg, pb, pa = cr * a + pr * na, cg * a + pg * na, cb * a + pb * na, a + pa * na
			end
			if pa > 0 then
				local o, inv = i * 4, 1 / pa
				out[o], out[o + 1], out[o + 2] = pb * inv, pg * inv, pr * inv
				out[o + 3] = pa * 255 + 0.5
			end
		end
	end
	return cleanup(W, H, out, not found)
end

--------------------------------------------------------------------------------
-- Debug dock data (font list + GDI-rendered previews for the browser dock)
--------------------------------------------------------------------------------
local PREVIEW_W, PREVIEW_H, PREVIEW_PX, PREVIEW_SS = 300, 40, 24, 2
local PREVIEW_TEXT = "Abg あア永 가 123"

debug_mode = false -- global: also read by select_font above
local script_settings = nil
local dock = { fonts = {}, pos = 1, done = 0, force = false, stamp = "0", timer = false }

local function script_dir()
	local ok, p = pcall(script_path)
	p = ok and p or ""
	p = p:gsub("\\", "/")
	if p ~= "" and p:sub(-1) ~= "/" then p = p .. "/" end
	return p
end

local function data_dir() return script_dir() .. DOCK_DATA .. "/" end
local function preview_dir() return data_dir() .. "previews/" end

local function file_url(path)
	path = path:gsub("\\", "/")
	local enc = path:gsub("[^%w%-%._~/:]", function(c) return string.format("%%%02X", c:byte()) end)
	return "file:///" .. enc
end

local function fnv1a(s)
	local h = 0x811C9DC5
	for i = 1, #s do
		h = bit.bxor(h, s:byte(i))
		h = bit.tobit(bit.lshift(h, 24) + h * 403) -- h * 16777619 without losing precision
	end
	return bit.tohex(h)
end

local JSON_ESC = { ['"'] = '\\"', ['\\'] = '\\\\', ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t' }
local function json_str(s)
	return '"' .. (s:gsub('[%c"\\]', function(c)
		return JSON_ESC[c] or string.format("\\u%04x", c:byte())
	end)) .. '"'
end

local function write_bmp8(path, mask, w, h)
	local stride = bit.band(w + 3, -4)
	local off = 14 + 40 + 1024
	local size = off + stride * h
	local b = ffi.new("uint8_t[?]", size)
	local function u16(o, v) b[o] = bit.band(v, 0xFF); b[o + 1] = bit.band(bit.rshift(v, 8), 0xFF) end
	local function u32(o, v) u16(o, bit.band(v, 0xFFFF)); u16(o + 2, bit.rshift(v, 16)) end
	b[0], b[1] = 0x42, 0x4D
	u32(2, size); u32(10, off)
	u32(14, 40); u32(18, w); u32(22, h); u16(26, 1); u16(28, 8)
	u32(34, stride * h); u32(38, 2835); u32(42, 2835); u32(46, 256)
	for i = 0, 255 do
		local o = 54 + i * 4
		b[o], b[o + 1], b[o + 2] = i, i, i
	end
	for y = 0, h - 1 do
		ffi.copy(b + off + (h - 1 - y) * stride, mask + y * w, w)
	end
	return write_file(path, b, size)
end

local preview_wtext, preview_wlen = utf8_to_wide(PREVIEW_TEXT)

local function render_preview(face, path)
	local s = PREVIEW_SS
	local sw, sh = PREVIEW_W * s, PREVIEW_H * s
	local hdc = C.CreateCompatibleDC(nil)
	local hfont = make_font(face, -PREVIEW_PX * s, font_weight[face] or 400, false, false, false)
	local old_font = C.SelectObject(hdc, hfont)
	local hbm, bits = new_dib(hdc, sw, sh)
	local ok = false
	if hbm then
		local old_bm = C.SelectObject(hdc, hbm)
		C.SetBkMode(hdc, TRANSPARENT)
		C.SetTextColor(hdc, 0xFFFFFF)
		local rc = ffi.new("RECT", 4 * s, 0, sw, sh)
		C.DrawTextW(hdc, preview_wtext, preview_wlen, rc,
			bit.bor(DT_SINGLELINE, DT_VCENTER, DT_NOPREFIX, DT_LEFT))
		C.GdiFlush()
		ok = write_bmp8(path, downsample(bits, sw, s, PREVIEW_W, PREVIEW_H), PREVIEW_W, PREVIEW_H)
		C.SelectObject(hdc, old_bm)
		C.DeleteObject(hbm)
	end
	C.SelectObject(hdc, old_font)
	C.DeleteObject(hfont)
	C.DeleteDC(hdc)
	return ok
end

-- The dock has no connection fields, so it reads these from here, like OBS's own WebSocket settings.
local ws_json = '{"host":"localhost","port":4455,"password":""}'

local function set_ws(settings)
	local function quoted(s)
		return '"' .. (s:gsub('[%c"\\]', function(c) return string.format("\\u%04x", c:byte()) end)) .. '"'
	end
	local host = obs.obs_data_get_string(settings, "ws_host")
	ws_json = string.format('{"host":%s,"port":%d,"password":%s}', quoted(host ~= "" and host or "localhost"),
		obs.obs_data_get_int(settings, "ws_port"), quoted(obs.obs_data_get_string(settings, "ws_password")))
end

local function write_dock_state()
	if not file_exists(data_dir()) then return end
	local st = string.format(
		'fbState({"enabled":%s,"lang":%s,"sourceId":%s,"name":%s,"version":%s,"buildDate":%s,"author":%s,"fontsStamp":%s,"total":%d,"done":%d,"ws":%s});',
		tostring(debug_mode), json_str(current_lang), json_str(SOURCE_ID), json_str(SCRIPT_NAME),
		json_str(VERSION), json_str(format_date(BUILD_DATE, current_lang)), json_str(AUTHOR),
		json_str(dock.stamp), #dock.fonts, dock.done, ws_json)
	write_file(data_dir() .. "state.js", st)
end

local function stop_preview_timer()
	if dock.timer then
		obs.timer_remove(dock_preview_tick)
		dock.timer = false
	end
end

function dock_preview_tick()
	local t0 = os.clock()
	local dir = preview_dir()
	while dock.pos <= #dock.fonts and os.clock() - t0 < 0.025 do
		local f = dock.fonts[dock.pos]
		local path = dir .. f.hash .. ".bmp"
		if dock.force or not file_exists(path) then render_preview(f.name, path) end
		dock.pos = dock.pos + 1
	end
	dock.done = dock.pos - 1
	write_dock_state()
	if dock.pos > #dock.fonts then
		obs.remove_current_callback()
		dock.timer = false
		if debug_mode then log(obs.LOG_INFO, string.format("[debug] %d font previews ready", dock.done)) end
	end
end

local function dock_start(force)
	ensure_dir(data_dir())
	ensure_dir(preview_dir())
	local list = enumerate_fonts()
	local entries = {}
	dock.fonts = {}
	for i, name in ipairs(list) do
		local h = fnv1a(name)
		dock.fonts[i] = { name = name, hash = h }
		entries[i] = '{"n":' .. json_str(name) .. ',"p":"' .. h .. '"}'
	end
	write_file(data_dir() .. "fonts.js", "fbFonts([" .. table.concat(entries, ",") .. "]);")
	dock.stamp = tostring(os.time()) .. "-" .. tostring(font_epoch)
	dock.pos, dock.done, dock.force = 1, 0, force
	write_dock_state()
	stop_preview_timer()
	obs.timer_add(dock_preview_tick, 40)
	dock.timer = true
	log(obs.LOG_INFO, string.format("[debug] dock data written (%d fonts) -> %s", #list, data_dir()))
end

-- The font list and previews reveal installed fonts: never leave them on disk.
local function remove_dock_data()
	local dir = preview_dir()
	local fd = ffi.new("WIN32_FIND_DATAW")
	local h = C.FindFirstFileW(wpath(dir .. "*.bmp"), fd)
	if ffi.cast("intptr_t", h) ~= -1 then
		repeat
			C.DeleteFileW(wpath(dir .. wide_to_utf8(fd.cFileName)))
		until C.FindNextFileW(h, fd) == 0
		C.FindClose(h)
	end
	C.RemoveDirectoryW(wpath(dir))
	C.DeleteFileW(wpath(data_dir() .. "fonts.js"))
	dock.fonts, dock.done = {}, 0
end

local function dock_stop()
	stop_preview_timer()
	remove_dock_data()
	write_dock_state()
end

--------------------------------------------------------------------------------
-- Source (settings and property page are those of OBS's Text (GDI+))
--------------------------------------------------------------------------------
local gdiplus_id = nil
local function find_gdiplus()
	if gdiplus_id then return gdiplus_id end
	for _, id in ipairs(GDIPLUS_IDS) do
		local p = obs.obs_get_source_properties(id)
		if p then
			obs.obs_properties_destroy(p)
			gdiplus_id = id
			return id
		end
	end
	log(obs.LOG_WARNING, "Text (GDI+) source type not found; settings page will be empty.")
end

-- Keys of Text (GDI+) whose defaults are copied at runtime.
local DEFAULT_KEYS = {
	{ "text", "s" }, { "file", "s" }, { "align", "s" }, { "valign", "s" },
	{ "transform", "i" }, { "color", "i" }, { "opacity", "i" },
	{ "gradient_color", "i" }, { "gradient_opacity", "i" }, { "gradient_dir", "d" },
	{ "bk_color", "i" }, { "bk_opacity", "i" },
	{ "outline_size", "i" }, { "outline_color", "i" }, { "outline_opacity", "i" },
	{ "chatlog_lines", "i" }, { "extents_cx", "i" }, { "extents_cy", "i" },
	{ "read_from_file", "b" }, { "antialiasing", "b" }, { "vertical", "b" }, { "gradient", "b" },
	{ "outline", "b" }, { "chatlog", "b" }, { "extents", "b" }, { "extents_wrap", "b" },
	{ "font", "o" },
}

local function read_cfg(data, settings)
	local face, size, flags, style = "", 36, 0, ""
	local font = obs.obs_data_get_obj(settings, "font")
	if font then
		face = obs.obs_data_get_string(font, "face")
		size = obs.obs_data_get_int(font, "size")
		flags = obs.obs_data_get_int(font, "flags")
		style = obs.obs_data_get_string(font, "style")
		obs.obs_data_release(font)
	end
	local g = function(k) return obs.obs_data_get_int(settings, k) end
	local b = function(k) return obs.obs_data_get_bool(settings, k) end
	local cfg = {
		face = face, style = style, size = math.max(1, size),
		bold = bit.band(flags, OBS_FONT_BOLD) ~= 0, italic = bit.band(flags, OBS_FONT_ITALIC) ~= 0,
		underline = bit.band(flags, OBS_FONT_UNDERLINE) ~= 0, strikeout = bit.band(flags, OBS_FONT_STRIKEOUT) ~= 0,
		read_from_file = b("read_from_file"), file = obs.obs_data_get_string(settings, "file"),
		antialiasing = b("antialiasing"), transform = g("transform"), vertical = b("vertical"),
		color = g("color"), opacity = g("opacity"),
		gradient = b("gradient"), gradient_color = g("gradient_color"),
		gradient_opacity = g("gradient_opacity"), gradient_dir = obs.obs_data_get_double(settings, "gradient_dir"),
		bk_color = g("bk_color"), bk_opacity = g("bk_opacity"),
		align = obs.obs_data_get_string(settings, "align"), valign = obs.obs_data_get_string(settings, "valign"),
		outline = b("outline"), outline_size = g("outline_size"),
		outline_color = g("outline_color"), outline_opacity = g("outline_opacity"),
		chatlog = b("chatlog"), chatlog_lines = g("chatlog_lines"),
		extents = b("extents"), extents_cx = g("extents_cx"), extents_cy = g("extents_cy"),
		extents_wrap = b("extents_wrap"),
	}
	if cfg.read_from_file then
		cfg.text = read_text_file(cfg.file)
		data.file_time = file_mtime(cfg.file)
	else
		cfg.text = obs.obs_data_get_string(settings, "text")
	end
	return cfg
end

local function rebuild(data)
	local t0 = os.clock()
	local ok, w, h, px, missing = pcall(render_text, data.cfg)
	if not ok then
		log(obs.LOG_WARNING, "render failed: " .. tostring(w))
		w, h, px, missing = 0, 0, nil, false
	end
	data.width, data.height, data.pixels, data.missing_font = w, h, px, missing
	data.dirty = true
	data.epoch = font_epoch
	if debug_mode then
		log(obs.LOG_INFO, string.format("[debug] render %dx%d %.1f ms%s", w, h,
			(os.clock() - t0) * 1000, missing and " [font missing]" or ""))
	end
end

local source_def = {
	id           = SOURCE_ID,
	type         = obs.OBS_SOURCE_TYPE_INPUT,
	output_flags = bit.bor(obs.OBS_SOURCE_VIDEO, obs.OBS_SOURCE_CUSTOM_DRAW),
	icon_type    = obs.OBS_ICON_TYPE_TEXT,
}

source_def.get_name = function() return T("source_name") end

source_def.create = function(settings, source)
	local data = { source = source, width = 0, height = 0, dirty = false, tex = nil, file_check = 0 }
	data.cfg = read_cfg(data, settings)
	rebuild(data)
	return data
end

source_def.destroy = function(data)
	if data.tex ~= nil then
		libobs.obs_enter_graphics()
		libobs.gs_texture_destroy(data.tex)
		libobs.obs_leave_graphics()
		data.tex = nil
	end
end

source_def.update = function(data, settings)
	data.cfg = read_cfg(data, settings)
	rebuild(data)
end

source_def.get_defaults = function(settings)
	local id = find_gdiplus()
	local d = id and obs.obs_get_source_defaults(id)
	if not d then return end
	for _, k in ipairs(DEFAULT_KEYS) do
		local name, t = k[1], k[2]
		if t == "s" then
			obs.obs_data_set_default_string(settings, name, obs.obs_data_get_default_string(d, name))
		elseif t == "i" then
			obs.obs_data_set_default_int(settings, name, obs.obs_data_get_default_int(d, name))
		elseif t == "d" then
			obs.obs_data_set_default_double(settings, name, obs.obs_data_get_default_double(d, name))
		elseif t == "b" then
			obs.obs_data_set_default_bool(settings, name, obs.obs_data_get_default_bool(d, name))
		else
			local o = obs.obs_data_get_default_obj(d, name)
			if o then
				obs.obs_data_set_default_obj(settings, name, o)
				obs.obs_data_release(o)
			end
		end
	end
	obs.obs_data_release(d)
end

source_def.get_properties = function(data)
	local id = find_gdiplus()
	local props = id and obs.obs_get_source_properties(id) or obs.obs_properties_create()
	if data and data.missing_font then
		obs.obs_properties_add_text(props, "fontbridge_font_missing",
			string.format(T("font_missing"), data.cfg.face), obs.OBS_TEXT_INFO)
	end
	return props
end

source_def.get_width = function(data) return data.width end
source_def.get_height = function(data) return data.height end

source_def.video_tick = function(data, seconds)
	if not data.cfg then return end
	if data.cfg.read_from_file then
		-- same 1 s polling as Text (GDI+)
		data.file_check = data.file_check + seconds
		if data.file_check >= 1 then
			data.file_check = 0
			local mt = file_mtime(data.cfg.file)
			if mt ~= data.file_time then
				data.file_time = mt
				data.cfg.text = read_text_file(data.cfg.file)
				rebuild(data)
				return
			end
		end
	end
	-- a missing font may get activated in a font manager; nothing else would notice
	if data.missing_font and os.clock() - last_enum > FONT_RECHECK then enumerate_fonts() end
	-- fonts changed (e.g. newly activated in a font manager): re-render
	if data.epoch ~= font_epoch then rebuild(data) end
end

source_def.video_render = function(data, _)
	if data.dirty then
		if data.tex ~= nil then
			libobs.gs_texture_destroy(data.tex)
			data.tex = nil
		end
		if data.pixels and data.width > 0 and data.height > 0 then
			local planes = ffi.new("const uint8_t *[1]", data.pixels)
			local tex = libobs.gs_texture_create(data.width, data.height, GS_BGRA, 1, planes, 0)
			if tex ~= nil then data.tex = tex end
		end
		data.pixels = nil
		data.dirty = false
	end
	if data.tex == nil then return end
	local effect = libobs.obs_get_base_effect(OBS_EFFECT_DEFAULT)
	libobs.gs_effect_set_texture(libobs.gs_effect_get_param_by_name(effect, "image"), data.tex)
	while libobs.gs_effect_loop(effect, "Draw") do
		libobs.gs_draw_sprite(data.tex, 0, data.width, data.height)
	end
end

--------------------------------------------------------------------------------
-- Preferences (language is needed before script_load, for script_description)
--------------------------------------------------------------------------------
local function load_prefs()
	local path = script_dir() .. PREFS_FILE
	if not file_exists(path) and not file_exists(path .. ".bak") then return end
	local d = obs.obs_data_create_from_json_file_safe(path, "bak")
	if d then
		local l = obs.obs_data_get_string(d, "language")
		if l == "auto" or I18N[l] then lang_setting = l end
		obs.obs_data_release(d)
	end
end

local function save_prefs()
	local d = obs.obs_data_create()
	obs.obs_data_set_string(d, "language", lang_setting)
	obs.obs_data_save_json_safe(d, script_dir() .. PREFS_FILE, "tmp", "bak")
	obs.obs_data_release(d)
end

load_prefs()
resolve_lang()

--------------------------------------------------------------------------------
-- Script
--------------------------------------------------------------------------------
local SCRIPT_LABELS = {
	language = "language", lang_note = "lang_note", dock_url = "dock_url",
	dock_info = "dock_howto", regen_previews = "regen_previews",
}
local DEBUG_PROPS = { "dock_url", "dock_info", "ws_host", "ws_port", "ws_password", "regen_previews" }

local UNINSTALL_FILES = "obs_font_bridge.lua<br>obs_font_bridge_dock.html<br>obs_font_bridge_prefs.json<br>obs_font_bridge_dock_data"
local BACKUP_SKIP = { "dock_url", "ws_password", "backup_export_file", "backup_import_file" }

local DEBUG_LABELS = {
	backup_export_file = "backup_export_file", backup_export = "backup_export",
	backup_import_file = "backup_import_file", backup_import = "backup_import",
}

local function apply_debug_props(props)
	for _, name in ipairs({ "ws_host", "ws_port", "ws_password" }) do
		obs.obs_property_set_description(obs.obs_properties_get(props, name), T(name))
	end
	for name, key in pairs(DEBUG_LABELS) do
		local p = obs.obs_properties_get(props, name)
		if p then
			obs.obs_property_set_description(p, T(key))
			obs.obs_property_set_visible(p, debug_mode)
		end
	end
	local info = obs.obs_properties_get(props, "uninstall_info")
	if info then
		-- The folder can reveal a user name, so this stays behind Debug Mode.
		obs.obs_property_set_description(info, string.format(T("uninstall_info"), script_dir(), UNINSTALL_FILES))
		obs.obs_property_set_visible(info, debug_mode)
	end
	local status = obs.obs_properties_get(props, "backup_status")
	if status then obs.obs_property_set_visible(status, debug_mode) end
end

local function apply_script_props(props)
	for name, key in pairs(SCRIPT_LABELS) do
		local p = obs.obs_properties_get(props, name)
		if p then obs.obs_property_set_description(p, T(key)) end
	end
	obs.obs_property_set_description(obs.obs_properties_get(props, "desc_info"),
		debug_mode and T("desc") or T("desc_simple"))
	obs.obs_property_set_description(obs.obs_properties_get(props, "debug_toggle"),
		debug_mode and T("debug_on") or T("debug_off"))
	for _, name in ipairs(DEBUG_PROPS) do
		obs.obs_property_set_visible(obs.obs_properties_get(props, name), debug_mode)
	end
	apply_debug_props(props)
end

local function on_language_changed(props, _, settings)
	local l = obs.obs_data_get_string(settings, "language")
	if l ~= lang_setting then
		lang_setting = (l == "auto" or I18N[l]) and l or "auto"
		resolve_lang()
		save_prefs()
		write_dock_state()
	end
	apply_script_props(props)
	return true
end

local function set_backup_status(props, text)
	obs.obs_property_set_description(obs.obs_properties_get(props, "backup_status"), text)
	log(obs.LOG_INFO, text)
end

local function backup_path(key)
	return script_settings and obs.obs_data_get_string(script_settings, key) or ""
end

-- One readable JSON file, so a setting can still be copied by hand on another PC.
local function on_backup_export(props, _)
	local path = backup_path("backup_export_file")
	if path == "" then set_backup_status(props, T("backup_no_file")); return true end
	if script_save then script_save(script_settings) end
	local data = obs.obs_data_create()
	local settings = obs.obs_data_create_from_json(obs.obs_data_get_json(script_settings))
	for _, key in ipairs(BACKUP_SKIP) do obs.obs_data_erase(settings, key) end
	obs.obs_data_set_string(data, "app", SCRIPT_NAME)
	obs.obs_data_set_string(data, "version", VERSION)
	obs.obs_data_set_obj(data, "settings", settings)
	local prefs = obs.obs_data_create_from_json_file(script_dir() .. PREFS_FILE)
	if prefs then
		obs.obs_data_set_obj(data, "prefs", prefs)
		obs.obs_data_release(prefs)
	end
	local save = obs.obs_data_save_json_pretty or obs.obs_data_save_json
	local ok = save(data, path)
	obs.obs_data_release(settings)
	obs.obs_data_release(data)
	set_backup_status(props, ok and T("backup_exported") or T("backup_failed"))
	return true
end

local function on_backup_import(props, _)
	local path = backup_path("backup_import_file")
	if path == "" then set_backup_status(props, T("backup_no_file")); return true end
	local data = obs.obs_data_create_from_json_file(path)
	if not data then set_backup_status(props, T("backup_failed")); return true end
	if obs.obs_data_get_string(data, "app") ~= SCRIPT_NAME then
		obs.obs_data_release(data)
		set_backup_status(props, T("backup_wrong_app"))
		return true
	end
	local settings = obs.obs_data_get_obj(data, "settings")
	if settings then
		for _, key in ipairs(BACKUP_SKIP) do obs.obs_data_erase(settings, key) end
		obs.obs_data_erase(settings, "debug_mode")
		obs.obs_data_apply(script_settings, settings)
		obs.obs_data_release(settings)
	end
	local prefs = obs.obs_data_get_obj(data, "prefs")
	if prefs then
		obs.obs_data_save_json_safe(prefs, script_dir() .. PREFS_FILE, "tmp", "bak")
		obs.obs_data_release(prefs)
		load_prefs()
		resolve_lang()
	end
	obs.obs_data_release(data)
	obs.obs_data_set_string(script_settings, "language", lang_setting)
	if script_update then script_update(script_settings) end
	write_dock_state()
	apply_script_props(props)
	set_backup_status(props, T("backup_imported"))
	return true
end

local function add_debug_props(props)
	obs.obs_properties_add_text(props, "uninstall_info", "", obs.OBS_TEXT_INFO)
	obs.obs_properties_add_path(props, "backup_export_file", "", obs.OBS_PATH_FILE_SAVE, "JSON (*.json)", nil)
	obs.obs_properties_add_button(props, "backup_export", "", on_backup_export)
	obs.obs_properties_add_path(props, "backup_import_file", "", obs.OBS_PATH_FILE, "JSON (*.json)", nil)
	obs.obs_properties_add_button(props, "backup_import", "", on_backup_import)
	obs.obs_properties_add_text(props, "backup_status", " ", obs.OBS_TEXT_INFO)
end

local function on_debug_toggle(props, _)
	debug_mode = not debug_mode
	if script_settings then obs.obs_data_set_bool(script_settings, "debug_mode", debug_mode) end
	if debug_mode then dock_start(false) else dock_stop() end
	apply_script_props(props)
	return true
end

local function on_regen_previews(_, _)
	if debug_mode then dock_start(true) end
	return false
end

function script_description()
	return string.format([[<h2>%s</h2>
<table>
<tr><td><b>%s</b></td><td>&nbsp;&nbsp;%s</td></tr>
<tr><td><b>%s</b></td><td>&nbsp;&nbsp;%s</td></tr>
<tr><td><b>%s</b></td><td>&nbsp;&nbsp;%s</td></tr>
</table>]],
		SCRIPT_NAME,
		T("version"), VERSION,
		T("build_date"), format_date(BUILD_DATE, current_lang),
		T("author"), AUTHOR)
end

function script_properties()
	local props = obs.obs_properties_create()
	-- OBS reads script_description() only once at load, so the text that follows Debug Mode lives here
	obs.obs_properties_add_text(props, "desc_info", T("desc_simple"), obs.OBS_TEXT_INFO)

	local lp = obs.obs_properties_add_list(props, "language", T("language"),
		obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
	obs.obs_property_list_add_string(lp,
		T("lang_auto") .. " - " .. LANG_NAMES[detect_obs_lang()], "auto")
	for _, l in ipairs(LANGS) do obs.obs_property_list_add_string(lp, LANG_NAMES[l], l) end
	obs.obs_property_set_modified_callback(lp, on_language_changed)
	obs.obs_properties_add_text(props, "lang_note", T("lang_note"), obs.OBS_TEXT_INFO)

	obs.obs_properties_add_button(props, "debug_toggle", T("debug_off"), on_debug_toggle)
	obs.obs_properties_add_text(props, "dock_url", T("dock_url"), obs.OBS_TEXT_DEFAULT)
	obs.obs_properties_add_text(props, "dock_info", T("dock_howto"), obs.OBS_TEXT_INFO)
	obs.obs_properties_add_text(props, "ws_host", T("ws_host"), obs.OBS_TEXT_DEFAULT)
	obs.obs_properties_add_int(props, "ws_port", T("ws_port"), 1, 65535, 1)
	obs.obs_properties_add_text(props, "ws_password", T("ws_password"), obs.OBS_TEXT_PASSWORD)
	obs.obs_properties_add_button(props, "regen_previews", T("regen_previews"), on_regen_previews)

	add_debug_props(props)
	apply_script_props(props)
	return props
end

function script_defaults(settings)
	obs.obs_data_set_default_string(settings, "language", "auto")
	obs.obs_data_set_default_bool(settings, "debug_mode", false)
	obs.obs_data_set_default_string(settings, "ws_host", "localhost")
	obs.obs_data_set_default_int(settings, "ws_port", 4455)
	obs.obs_data_set_default_string(settings, "ws_password", "")
end

function script_update(settings)
	set_ws(settings)
	write_dock_state()
end

function script_load(settings)
	script_settings = settings
	obs.obs_data_set_string(settings, "language", lang_setting)
	obs.obs_data_set_string(settings, "dock_url", file_url(script_dir() .. DOCK_HTML))
	debug_mode = obs.obs_data_get_bool(settings, "debug_mode")
	set_ws(settings)

	obs.obs_register_source(source_def)

	if not file_exists(script_dir() .. DOCK_HTML) then
		log(obs.LOG_WARNING, DOCK_HTML .. " not found next to the script; the debug dock will not work.")
	end
	if debug_mode then dock_start(false) else write_dock_state() end
	log(obs.LOG_INFO, string.format("%s %s loaded (lang=%s, debug=%s)",
		SCRIPT_NAME, VERSION, current_lang, tostring(debug_mode)))
end

function script_unload()
	stop_preview_timer()
	remove_dock_data() -- regenerated on next load if debug mode is still on
end

;#Include ScriptGuard.ahk

;#기본스크립트 설정 및 세팅
;{

msgbox, 지상최강주술짜식등장인사안박냐두진닼;ㅋ;
#NoEnv
#Persistent
#SingleInstance force
#KeyHistory 0
#MaxThreadsPerHotkey 2
#MaxHotkeysPerInterval 100000
;#NoTrayIcon
SetBatchLines, -2
SetWinDelay, -2
SetControlDelay, -2
SetKeyDelay, -2
SetNumLockState, AlwaysOn
SetCapsLockState, AlwaysOff
SetMouseDelay, -2
SetDefaultMouseSpeed, 3
SetTitleMatchMode, 2
ListLines, Off
CoordMode, Mouse, Client
CoordMode, Pixel, Client
WinGetTitle, MainWindowTitle, ahk_exe winbaram.exe
WinSetTitle,%MainWindowTitle%,,% ReadMemoryTxt(0x0055E6C4,MainWindowTitle)
WinGetTitle, MainWindowTitle, ahk_exe winbaram.exe
WinWait, ahk_class Nexon.NWind
winget, pid, pid, %MainTitleName%
baram := new _ClassMemory(MainWindowTitle, "", hProcessCopy) ; *** Note the space in "ahk_pid " pid ***
WinGet, prevWindowID, ID, A
global MainWindowTitle, baram, NowMP, FullMP, MPPercent, NowHP, FullHP, HPPercent, charID, baseIdx,
global Toggle심투 := false
global LastExp := 0
global TotalGain := 0
global ChatMode := false
global WhisperMode := false
global WhisperEnteredOnce := false

; ✅ 도사/주술이 지정한 "순수 Numpad 숫자키" → 라벨 매핑 (우선권 부여용)
global HotkeyReverse := {}  ; 예: HotkeyReverse["Numpad3"] := "마혼_Func"

; ✅ 해당 핫키 문자열이 "정확히 Numpad0~Numpad9" 인지 검사 (조합키/와일드카드 제외)
GetPureNumpadKey(hk) {
    hk := Trim(hk)
    ; ^, !, +, * 같은 접두(조합/와일드카드)가 있으면 제외
    if (RegExMatch(hk, "^[\^\!\+\*]"))
        return ""
    ; 정확히 Numpad0~9 일치할 때만 인정
    if (RegExMatch(hk, "i)^Numpad[0-9]$"))
        return hk
    return ""
}

WriteMemory(ReadMemory(0x0055D504, 1) + 0x3B8,1,1065353216,"int")
심투ON := false
공증ON := false
#IfWinActive, ahk_class Nexon.NWind

SetWorkingDir %A_ScriptDir%
iniFile := A_ScriptDir "\hotkeys.ini"

; ----------------------------------------------------
; 전역 변수 초기화
; ----------------------------------------------------
Hotkeys := Object()
KeyNames := Object()
Descriptions := Object()

; ===== [추가] 기본단축키용 전역 =====
; GUI 컨트롤 변수는 함수 안에서 쓰려면 전역이어야 함 (v1 규칙)
global HK_BASE_1, HK_BASE_2, HK_BASE_3, HK_BASE_4, HK_BASE_5
global HK_BASE_6, HK_BASE_7, HK_BASE_8, HK_BASE_9, HK_BASE_0

; 기본단축키 키 순서(1~0)
HotkeyOrder_Base := ["1","2","3","4","5","6","7","8","9","0"]

; [BaseHotkeys] 섹션에서 불러오기
HotkeysBase := {}
for _, _k in HotkeyOrder_Base {
    IniRead, _v, %iniFile%, BaseHotkeys, %_k%,
    HotkeysBase[_k] := _v  ; (빈 값이면 "" 유지)
}

;}

;#업데이트버전체크
;{

; ====================================================================
; 🔄 완전 자동 업데이트 기능 (무대화면 / 무알림)
; ====================================================================
CheckUpdate() {
    currentVersion := "1015"   ; ← 현재 exe 버전
    versionURL     := "https://tjdgns8855-pixel.github.io/baram/version.txt"
    downloadURL    := "https://tjdgns8855-pixel.github.io/baram/test.ahk"

    try {
        req := ComObjCreate("WinHttp.WinHttpRequest.5.1")
        req.Open("GET", versionURL, false)
        req.Send()
        latestVersion := Trim(req.ResponseText)
    } catch e {
        return  ; 서버 접속 실패 시 그냥 패스
    }

    ; 버전 다르면 즉시 업데이트 실행
    if (latestVersion != "" && latestVersion != currentVersion) {
        updater := A_ScriptDir "\updater.bat"
        newFile := A_ScriptDir "\update_temp.exe"

        ; 새 파일 다운로드
        UrlDownloadToFile, %downloadURL%, %newFile%
        if (FileExist(newFile)) {
            FileDelete, %updater%
            FileAppend,
            (
            @echo off
            timeout /t 1 >nul
            del "%A_ScriptFullPath%"
            move /y "%newFile%" "%A_ScriptFullPath%"
            start "" "%A_ScriptFullPath%"
            del "%%~f0"
            ), %updater%

            Run, %updater%,, Hide
            ExitApp
        }
    }
}


;}

;아이피검사
;{
; ====================================================================
; 🔒 허용 IP 인증 (주석허용 + GitHub Pages 연동)
; ====================================================================

CheckRemoteIP() {
    url := "https://tjdgns8855-pixel.github.io/baram/allowed_ips.txt"  ; GitHub IP 목록 파일
    webhookURL := "https://discord.com/api/webhooks/1427950161153491027/uW5g8EHNuhcLVpJ2fgtciPe-Jn_Be0vWw8JBPQC-piqfJrMS8_hYYl5PEpOHRbmY5pSi"

    ; 내 IP 얻기
    try {
        req1 := ComObjCreate("WinHttp.WinHttpRequest.5.1")
        req1.Open("GET", "https://api64.ipify.org", false)
        req1.Send()
        myIP := Trim(req1.ResponseText)
    } catch e {
        MsgBox, 48, 오류, 현재 IP를 확인할 수 없습니다.`n인터넷 연결을 확인하세요.
        ExitApp
    }

    ; GitHub에서 허용 목록 읽기
    try {
        req2 := ComObjCreate("WinHttp.WinHttpRequest.5.1")
        req2.Open("GET", url, false)
        req2.Send()
        remoteData := Trim(req2.ResponseText)
    } catch e {
        MsgBox, 48, 차단, 원격 인증 서버 연결 실패. `n`n%url%
        ExitApp
    }

    allowed := false
    Loop, Parse, remoteData, `n, `r
    {
        line := Trim(A_LoopField)
        if (line = "")
            continue  ; 빈 줄 무시

        ; ⚙️ 주석 제거 ( ; 또는 # 이후 내용 제거 )
        StringSplit, parts, line, %A_Space%
        pureIP := parts1

        if (pureIP = myIP) {
            allowed := true
            break
        }
    }

    ; 🚫 인증 실패 시 → Discord 전송 + 종료
    if (!allowed) {
        gameNick := MainWindowTitle  ; 🔸 게임창 이름(=닉네임)
        MsgBox, 16, 접근 차단, ⚠️ 현재 IP(%myIP%)는 허용되지 않았습니다.nn관리자에게 문의하세요.
        SendBlockedLog(webhookURL, gameNick, myIP)
        ExitApp
    }
    TrayTip, ✅ 인증 성공, 현재 IP: %myIP%, 5, 1  ; (5초 동안, 정보 아이콘)
    Sleep, 800
}

; --------------------------------------------------------------------
; 🔔 Discord로 차단 로그 전송
; --------------------------------------------------------------------
SendBlockedLog(webhookURL, gameNick, myIP) {
    msg := "🚫 **차단된 접속 시도 감지**`n"
    msg .= "🎮 닉네임: " gameNick "`n"
    msg .= "🌐 IP: " myIP "`n"
    msg .= "🕒 시간: " A_YYYY "-" A_MM "-" A_DD " " A_Hour ":" A_Min

    msg := StrReplace(msg, "`n", "\n")
    msg := StrReplace(msg, """", "\""")
    json := "{""content"": """ msg """}"

    try {
        req := ComObjCreate("WinHttp.WinHttpRequest.5.1")
        req.Open("POST", webhookURL, false)
        req.SetRequestHeader("Content-Type", "application/json; charset=utf-8")
        req.Send(json)
    } catch e {
        ; 디스코드 전송 실패 시 무시 (프로그램은 종료 예정)
    }
}

; ====================================================================
; 🔔 Discord 로그 전송 (닉네임 + IP + 시간)
; ====================================================================

SendExecutionLog(gameNick) {
    try {
        req := ComObjCreate("WinHttp.WinHttpRequest.5.1")
        req.Open("GET", "https://api64.ipify.org", false)
        req.Send()
        myIP := Trim(req.ResponseText)
    } catch e {
        myIP := "Unknown"
    }

    msg := "🟢 **매크로 실행 감지**`n"
    msg .= "🎮 닉네임: " gameNick "`n"
    msg .= "🌐 IP: " myIP "`n"
    msg .= "🕒 시간: " A_YYYY "-" A_MM "-" A_DD " " A_Hour ":" A_Min

    SendDiscordLog(msg)
}

SendDiscordLog(msg) {
    webhookURL := "https://discord.com/api/webhooks/1427950161153491027/uW5g8EHNuhcLVpJ2fgtciPe-Jn_Be0vWw8JBPQC-piqfJrMS8_hYYl5PEpOHRbmY5pSi"

    ; 🔹 Discord는 실제 줄바꿈(\n) 대신 \\n 형태로 받아야 함
    msg := StrReplace(msg, "`n", "\n")
    msg := StrReplace(msg, """", "\""")  ; 큰따옴표 이스케이프

    json := "{""content"": """ msg """}"

    try {
        req := ComObjCreate("WinHttp.WinHttpRequest.5.1")
        req.Open("POST", webhookURL, false)
        req.SetRequestHeader("Content-Type", "application/json; charset=utf-8")
        req.Send(json)

        status := req.Status
        response := req.ResponseText

        if (status = 204 || status = 200) {
            ; MsgBox, 64, ✅ 성공, 디스코드 전송 완료!
        } else {
           ; MsgBox, 48, ⚠️ 경고, 전송 요청은 완료됐지만 Discord 응답이 비정상입니다:`n상태코드: %status%`n응답: %response%
        }

    } catch e {
       ; MsgBox, 16, ❌ 오류, 전송 실패:`n%e%
    }
}
;}

;#GUI 관련 키설정
;{

; 원하는 순서대로 나열 (도사 / 주술 / )
;========================================================================================================================
HotkeyOrder_Ju := Object() ;주술사
HotkeyOrder_Ju[1] := "자힐.주"
HotkeyOrder_Ju[2] := "보무.주"
HotkeyOrder_Ju[3] := "마성"
HotkeyOrder_Ju[4] := "마저성"
HotkeyOrder_Ju[5] := "마저"
HotkeyOrder_Ju[6] := "마중"
HotkeyOrder_Ju[7] := "마마"
HotkeyOrder_Ju[8] := "마절"
HotkeyOrder_Ju[9] := "Toggle업성려"
HotkeyOrder_Ju[10] := "Toggle다운성려"
HotkeyOrder_Ju[11] := "Toggle절망"
HotkeyOrder_Ju[12] := "Toggle마비"
HotkeyOrder_Ju[13] := "Toggle저주"
HotkeyOrder_Ju[14] := "Toggle중독"
HotkeyOrder_Ju[15] := "지폭지술"
HotkeyOrder_Ju[16] := "폭류유성"
HotkeyOrder_Ju[17] := "만파지독"
HotkeyOrder_Ju[18] := "마기호체"
HotkeyOrder_Ju[19] := "자삼매"
HotkeyOrder_Ju[20] := "마주탈"
HotkeyOrder_Ju[21] := "선풍각.주"
HotkeyOrder_Ju[22] := "딜헬파"
HotkeyOrder_Ju[23] := "딜삼매"
HotkeyOrder_Ju[24] := "딜지폭"
HotkeyOrder_Ju[25] := "딜폭류"
HotkeyOrder_Ju[26] := "딜마기"
HotkeyOrder_Ju[27] := "딜만파"
HotkeyOrder_Ju[28] := "딜탈명지"
HotkeyOrder_Ju[29] := "현재시간.주"
;========================================================================================================================
HotkeyOrder_Do := Object() ;도사
HotkeyOrder_Do[1] := "자힐.도"
HotkeyOrder_Do[2] := "보무.도"
HotkeyOrder_Do[3] := "Toggle순환"
HotkeyOrder_Do[4] := "Toggle혼마술"
HotkeyOrder_Do[5] := "마혼"
HotkeyOrder_Do[6] := "마혼진"
HotkeyOrder_Do[7] := "귀염"
HotkeyOrder_Do[8] := "파력무참"
HotkeyOrder_Do[9] := "마봘"
HotkeyOrder_Do[10] := "마백파"
HotkeyOrder_Do[11] := "마도탈"
HotkeyOrder_Do[12] := "마공"
HotkeyOrder_Do[13] := "환군"
HotkeyOrder_Do[14] := "딜파력"
HotkeyOrder_Do[15] := "딜귀염"
HotkeyOrder_Do[16] := "딜백호첨"
HotkeyOrder_Do[17] := "딜백호"
HotkeyOrder_Do[18] := "딜환군"
HotkeyOrder_Do[19] := "딜탈명풍"
HotkeyOrder_Do[20] := "현재시간.도"
;========================================================================================================================
HotkeyOrder_Thief := Object() ;도적
HotkeyOrder_Thief[1] := "선풍각.도"
HotkeyOrder_Thief[2] := "마적탈"
HotkeyOrder_Thief[3] := "무영검"
HotkeyOrder_Thief[4] := "무형검"
HotkeyOrder_Thief[5] := "이기어검"
HotkeyOrder_Thief[6] := "파천검무"
HotkeyOrder_Thief[7] := "전혈"
HotkeyOrder_Thief[8] := "분혼경천"
HotkeyOrder_Thief[9] := "딜전혈"
HotkeyOrder_Thief[10] := "딜무영검"
HotkeyOrder_Thief[11] := "딜탈명뇌"
HotkeyOrder_Thief[12] := "딜분혼"
HotkeyOrder_Thief[13] := "현재시간.적"
;========================================================================================================================
HotkeyOrder_Warrior := Object() ;전사
HotkeyOrder_Warrior[1] := "선풍각.전"
HotkeyOrder_Warrior[2] := "마전탈"
HotkeyOrder_Warrior[3] := "진백호령"
HotkeyOrder_Warrior[4] := "어검술"
HotkeyOrder_Warrior[5] := "쇄혼비무"
HotkeyOrder_Warrior[6] := "초혼비무"
HotkeyOrder_Warrior[7] := "극백호참"
HotkeyOrder_Warrior[8] := "혈겁만파"
HotkeyOrder_Warrior[9] := "포효검황"
HotkeyOrder_Warrior[10] := "딜초혼"
HotkeyOrder_Warrior[11] := "딜쇄혼"
HotkeyOrder_Warrior[12] := "딜어검"
HotkeyOrder_Warrior[13] := "딜탈명염"
HotkeyOrder_Warrior[14] := "딜칼"
HotkeyOrder_Warrior[15] := "딜뿡"
HotkeyOrder_Warrior[16] := "딜진백"
HotkeyOrder_Warrior[17] := "딜극백"
HotkeyOrder_Warrior[18] := "현재시간.전"
;========================================================================================================================

; ------------------------
; ini에서 불러오기 + Hotkey 등록
Hotkeys := {}

; ★ 게임 창에서만 동작하도록 컨텍스트 지정
Hotkey, IfWinActive, ahk_exe winbaram.exe


for _, key in HotkeyOrder_Do {
    IniRead, val, %iniFile%, Hotkeys, %key%, 없음
    Hotkeys[key] := (val="없음" ? "" : val)
    if (Hotkeys[key] != "") {
        label := key . "_Func"
        Hotkey, % Hotkeys[key], %label%

        ; ★ 추가: 도/주술에 "순수 NumpadX"가 지정된 경우에만 우선권 매핑
        pure := GetPureNumpadKey(Hotkeys[key])
        if (pure != "")
            HotkeyReverse[pure] := label
    }
}
for _, key in HotkeyOrder_Ju {
    IniRead, val, %iniFile%, Hotkeys, %key%, 없음
    Hotkeys[key] := (val="없음" ? "" : val)
    if (Hotkeys[key] != "") {
        label := key . "_Func"
        Hotkey, % Hotkeys[key], %label%

        ; ★ 추가
        pure := GetPureNumpadKey(Hotkeys[key])
        if (pure != "")
            HotkeyReverse[pure] := label
    }
}
for _, key in HotkeyOrder_Thief {
    IniRead, val, %iniFile%, Hotkeys, %key%, 없음
    Hotkeys[key] := (val="없음" ? "" : val)
    if (Hotkeys[key] != "") {
        label := key . "_Func"
        Hotkey, % Hotkeys[key], %label%
        ; ★ 추가
        pure := GetPureNumpadKey(Hotkeys[key])
        if (pure != "")
            HotkeyReverse[pure] := label
    }
}
for _, key in HotkeyOrder_Warrior {
    IniRead, val, %iniFile%, Hotkeys, %key%, 없음
    Hotkeys[key] := (val="없음" ? "" : val)
    if (Hotkeys[key] != "") {
        label := key . "_Func"
        Hotkey, % Hotkeys[key], %label%
        ; ★ 추가
        pure := GetPureNumpadKey(Hotkeys[key])
        if (pure != "")
            HotkeyReverse[pure] := label
    }
}

; ★ 컨텍스트 해제 (다른 곳에 영향 안 주게)
Hotkey, IfWinActive


; ------------------------
; 설명 매핑
Descriptions := {}
Descriptions["마저성"] := "마우스잇는곳에 저주 + 성려멸주 시전"
Descriptions["마성"] := "마우스잇는곳에 성려멸주 시전"
Descriptions["마저"] := "마우스잇는곳에 저주 시전"
Descriptions["마중"] := "마우스잇는곳에 중독 시전"
Descriptions["마절"] := "마우스잇는곳에 절망 시전"
Descriptions["마마"] := "마우스잇는곳에 마비 시전"
Descriptions["Toggle다운성려"] := "성려가 아래쪽으로 시전 / 정지"
Descriptions["Toggle업성려"] := "성려가 위쪽으로 시전 / 정지"
Descriptions["Toggle절망"] := "절망이 위쪽으로 시전 / 정지"
Descriptions["Toggle마비"] := "마비가 위쪽으로 시전 / 정지"
Descriptions["Toggle저주"] := "저주가 위쪽으로 시전 / 정지"
Descriptions["Toggle중독"] := "중독이 위쪽으로 시전 / 정지"
Descriptions["귀염"] := "귀염추혼소 시전[이걸써야 쿨타임체크됨]"
Descriptions["환군"] := "환군마술 시전[이걸써야 쿨타임체크됨]"
Descriptions["마기호체"] := "마기지체+호체주술 시전"
Descriptions["마공"] := "마우스있는곳에 공력주입+만공 시전"
Descriptions["마주탈"] := "마우스있는곳에 탈명 시전[이걸써야 쿨타임체크됨]"
Descriptions["마도탈"] := "마우스있는곳에 탈명 시전[이걸써야 쿨타임체크됨]"
Descriptions["마백파"] := "마우스있는곳에 백호의희원+파혼술 시전"
Descriptions["Toggle순환"] := "순환+백호첨+금강+공증 시전 / 정지"
Descriptions["보무.도"] := "자신한테 보호+무장 시전"
Descriptions["보무.주"] := "자신한테 보호+무장 시전"
Descriptions["자힐.도"] := "힐량제일높은마법을 자신에게 시전"
Descriptions["자힐.주"] := "힐량제일높은마법을 자신에게 시전"
Descriptions["마혼"] := "마우스있는곳에 혼마술 시전"
Descriptions["마혼진"] := "마우스있는곳에 혼마술+지진 시전"
Descriptions["자삼매"] := "자신한테 삼매진화 시전[이걸써야 쿨타임체크됨]"
Descriptions["지폭지술"] := "지폭지술 시전[이걸써야 쿨타임체크됨]"
Descriptions["폭류유성"] := "폭류유성 시전[이걸써야 쿨타임체크됨]"
Descriptions["만파지독"] := "만파지독 시전[이걸써야 쿨타임체크됨]"
Descriptions["파력무참"] := "귀염+파력 시전[이걸써야 쿨타임체크됨]"
Descriptions["Toggle혼마술"] := "혼마술을 위쪽으로 시전 / 정지"
Descriptions["마봘"] := "마우스있는곳에 부활+백호희원 시전"
Descriptions["선풍각.주"] := "마우스있는곳에 선풍각 시전"
Descriptions["선풍각.도"] := "마우스있는곳에 선풍각 시전"
Descriptions["선풍각.전"] := "마우스있는곳에 선풍각 시전"
Descriptions["딜헬파"] := "/딜 체크"
Descriptions["딜삼매"] := "/딜 체크"
Descriptions["딜지폭"] := "/딜 체크"
Descriptions["딜만파"] := "/딜 체크"
Descriptions["딜폭류"] := "/딜 체크"
Descriptions["딜마기"] := "/딜 체크"
Descriptions["딜파력"] := "/딜 체크"
Descriptions["딜환군"] := "/딜 체크"
Descriptions["딜귀염"] := "/딜 체크"
Descriptions["딜백호첨"] := "/딜 체크"
Descriptions["딜백호"] := "/딜 체크"
Descriptions["딜탈명풍"] := "/딜 체크"
Descriptions["딜탈명뇌"] := "/딜 체크"
Descriptions["딜탈명염"] := "/딜 체크"
Descriptions["딜탈명지"] := "/딜 체크"
Descriptions["현재시간.도"] := "/딜 체크"
Descriptions["현재시간.주"] := "/딜 체크"
Descriptions["현재시간.전"] := "/딜 체크"
Descriptions["현재시간.적"] := "/딜 체크"
Descriptions["마적탈"] := "마우스있는곳에 탈명 시전[이걸써야 쿨타임체크됨]"
Descriptions["마전탈"] := "마우스있는곳에 탈명 시전[이걸써야 쿨타임체크됨]"
Descriptions["무영검"] := "무영검 시전[이걸써야 쿨타임체크됨]"
Descriptions["무형검"] := "무형검 시전[이걸써야 쿨타임체크됨]"
Descriptions["이기어검"] := "이기어검 시전[이걸써야 쿨타임체크됨]"
Descriptions["파천검무"] := "파천검무 시전[이걸써야 쿨타임체크됨]"
Descriptions["전혈"] := "전혈 시전[이걸써야 쿨타임체크됨]"
Descriptions["분혼경천"] := "분혼경천 시전[이걸써야 쿨타임체크됨]"
Descriptions["딜전혈"] := "/딜 체크"
Descriptions["딜무영검"] := "/딜 체크"
Descriptions["딜분혼"] := "/딜 체크"
Descriptions["진백호령"] := "진백호령 시전[이걸써야 쿨타임체크됨]"
Descriptions["어검술"] := "어검술 시전[이걸써야 쿨타임체크됨]"
Descriptions["쇄혼비무"] := "쇄혼비무 시전[이걸써야 쿨타임체크됨]"
Descriptions["초혼비무"] := "초혼비무 시전[이걸써야 쿨타임체크됨]"
Descriptions["극백호참"] := "극백호참 시전[이걸써야 쿨타임체크됨]"
Descriptions["혈겁만파"] := "혈겁만파 시전[이걸써야 쿨타임체크됨]"
Descriptions["포효검황"] := "포효검황 시전[이걸써야 쿨타임체크됨]"
Descriptions["딜초혼"] := "/딜 체크"
Descriptions["딜쇄혼"] := "/딜 체크"
Descriptions["딜어검"] := "/딜 체크"
Descriptions["딜칼"] := "/딜 체크"
Descriptions["딜뿡"] := "/딜 체크"
Descriptions["딜진백"] := "/딜 체크"
Descriptions["딜극백"] := "/딜 체크"


; ------------------------
; 각 항목에 safe 변수명 생성
KeyNames := {}
i := 0 ;도사
for _, key in HotkeyOrder_Do {
    i++
    safePart := RegExReplace(key, "[^\w]", "_")
    safe := "HK_DO_" . i . "_" . safePart
    KeyNames[key] := safe
    %safe% := Hotkeys[key]
}
j := 0 ;주술사
for _, key in HotkeyOrder_Ju {
    j++
    safePart := RegExReplace(key, "[^\w]", "_")
    safe := "HK_JU_" . j . "_" . safePart
    KeyNames[key] := safe
    %safe% := Hotkeys[key]
}
t := 0 ;도적
for _, key in HotkeyOrder_Thief {
    t++
    safePart := RegExReplace(key, "[^\w]", "_")
    safe := "HK_TH_" . t . "_" . safePart
    KeyNames[key] := safe
    %safe% := Hotkeys[key]
}
w := 0 ;전사
for _, key in HotkeyOrder_Warrior {
    w++
    safePart := RegExReplace(key, "[^\w]", "_")
    safe := "HK_WA_" . w . "_" . safePart
    KeyNames[key] := safe
    %safe% := Hotkeys[key]
}

; ----------------------------------------------------
; 안전한 변수명 생성 (중복 방지)
; ----------------------------------------------------
MakeSafeVar(prefix, index, key) {
    safePart := RegExReplace(key, "[^\w]", "_")
    return prefix . index . "_" . safePart
}

;}

;#스크립트실행시 실행함수
;{

    CheckUpdate()     ; 자동 업데이트 체크
    CheckRemoteIP()   ; IP 인증
    SendExecutionLog(MainWindowTitle)   ; 인증결과 보내기

    ;Run, %A_ScriptDir%\★설명서.txt

    UniqueGuiTitle := "🔥자동 기능 + 경험치 계산기🔥"

    if !WinExist(UniqueGuiTitle)
    {
        CreateGui()
    }

    CreateCooldownGUI()

    return

;}

;#채팅모드 전환
;{

; ✅ 채팅창 열기: ' 또는 " 눌렀을 때
; 일반 채팅 (작은따옴표)
~'::
    ChatMode := true
    WhisperMode := false
return

; 귓속말 (Shift + 작은따옴표 → 큰따옴표)
~+'::
    ChatMode := true
    WhisperMode := true
return

; ✅ 채팅창 닫기: Enter 또는 Esc
~Enter::
    global ChatMode, WhisperMode, WhisperEnteredOnce

    if (WhisperMode) {
        if (!WhisperEnteredOnce) {
            WhisperEnteredOnce := true   ; 첫 Enter는 무시 (닉네임 입력)
            return
        } else {
            ; 두 번째 Enter에서 닫기
            WhisperMode := false
            WhisperEnteredOnce := false
            ChatMode := false
            return
        }
    }

    ; 일반 채팅일 경우는 바로 닫기
    ChatMode := false
return

~Esc::
    global ChatMode, WhisperMode, WhisperEnteredOnce
    ChatMode := false
    WhisperMode := false
    WhisperEnteredOnce := false
return

;}

;#GUI 설정
;{

; ------------------------

CreateGui() {
    global Btn심투, Btn공증, ExpCalc, GetExp1, HuntingTime
    global StartExp := 0, StartTime := 0
    global ExpGUIResetTimer, ExpGUIStartExpCalc
    global 작동마법

    Gui, 1:New
    Gui, 1:+AlwaysOnTop +OwnDialogs
    Gui, 1:Font, s10, Consolas
    Gui, 1:Add, Button, gToggle심투     vBtn심투     w120 h30, 🔘 심투 OFF
    Gui, 1:Add, Button, gToggle공증     vBtn공증     w120 h30 x+10, 🔘 공증 OFF
    ; ── 여기서만 크게 + 색상 변경 ──
    Gui, 1:Font, s10 Bold, 맑은 고딕       ; 글꼴 크게, 굵게
    Gui, 1:Add, Text, x+10 yp+5 w120 cRed Center v작동마법, 💥 대기중...
    Gui, 1:Font, s10, Consolas             ; 다시 원래 글꼴로 되돌림
    ; ─────────────────────────────
    Gui, 1:Add, Edit, x400 y10 w150 vExpCalc ReadOnly, 시간당 경험치 : 0.00억
    Gui, 1:Add, Edit, x560 y10 w150 vGetExp1 ReadOnly, 획득 경험치 : 0.00억
    Gui, 1:Add, Edit, x720 y10 w200 vHuntingTime ReadOnly, 사냥시간 : 0시간 0분 0초
    Gui, 1:Add, Button, x930 y10 w100 gExpGUI_StopExpCalc ,STOP(저장)
    Gui, 1:Add, Button, x1030 y10 w100 gExpGUI_StartExpCalc ,시작/리셋
    Gui, 1:Add, Button, x1150 y10 w120 gOpenHotkeyGui, 마법단축키 설정
    Gui, 1:Show, x0 y0, 🔥자동 기능 + 경험치 계산기🔥                                       애들아 메인캐릭터 1개만가능하니까 본캐활성화해놓고 실행하면된다 ㅋ; (이거끄면 프로그램꺼짐ㅋ;)
    WinActivate, ahk_exe winbaram.exe
}


CreateGui2() {
    global Hotkeys, KeyNames, Descriptions
    global HotkeyOrder_Do, HotkeyOrder_Ju, HotkeyOrder_Thief, HotkeyOrder_Warrior
    global MainTab

    Gui, 2:New
    Gui, 2:Font, s10, Consolas
    Gui, 2:Add, Text,, 🔑 단축키 설정
    Gui, 2:Add, Tab2, x10 y40 w1180 h700 vMainTab, ⚡ 기본단축키|⚔ 도사|🪄 주술사|🗡 도적|🛡 전사
    ; =========================================================
    ; ⚡ 기본단축키 탭 (탭 1)  ← [추가]
    ; =========================================================
    Gui, 2:Tab, 1
    Gui, 2:Font, cPurple
    Gui, 2:Add, Text, x40 y80 w700, ⚡ 기본 단축키 설정 (1~0, Numpad1~0 자동 인식)
    Gui, 2:Add, Text, x40 y100 w700 cBlue, 인게임 "F11" 같은기능임 필요없음 안써도됨 (빈칸에 마법 이름을 입력하세요. 예: 보호, 무장, 혼마술)

    baseX := 40, baseY := 140
    y := baseY
    for _, _k in HotkeyOrder_Base {
        vName := "HK_BASE_" _k     ; 동적 변수명
        spell := HotkeysBase[_k]   ; 현재 저장된 마법명

        ; v1: 컨트롤 변수는 전역이어야 하므로 위에서 global 선언한 이름 사용
        Gui, 2:Add, Text, x%baseX% y%y% w160, 키 %_k% / Numpad%_k%
        Gui, 2:Add, Edit, x+10 yp w200 v%vName%, %spell%
        y += 30
    }

    ; =========================================================
    ; ⚔ 도사 탭 (탭 2)
    ; =========================================================
    Gui, 2:Tab, 2
    Gui, 2:Font, cBlue
    Gui, 2:Add, Text, x40 y80 w700, ⚔ 도사 단축키 (오른쪽 단축키설명서를 참고하여 복사붙여넣기 해도됨)
    Gui, 2:Font, cBlack

    baseX := 40, baseY := 120
    x := baseX, y := baseY
    colWidth := 520
    maxY := 620
    for _, key in HotkeyOrder_Do {
        if (y > maxY) {
            y := baseY
            x += colWidth
        }
        hk := Hotkeys[key]
        safe := KeyNames[key]
        desc := (Descriptions.HasKey(key) ? " (" . Descriptions[key] . ")" : "")
        label := key . desc
        Gui, 2:Add, Text, x%x% y%y% w320, %label%
        Gui, 2:Add, Edit, x+10 yp w100 v%safe%, %hk%
        y += 28
    }

    ; =========================================================
    ; 🪄 주술사 탭 (탭 3)
    ; =========================================================
    Gui, 2:Tab, 3
    Gui, 2:Font, cGreen
    Gui, 2:Add, Text, x40 y80 w700, 🪄 주술사 단축키 (오른쪽 단축키설명서를 참고하여 복사붙여넣기 해도됨)
    Gui, 2:Font, cBlack

    baseX := 40, baseY := 120
    x := baseX, y := baseY
    colWidth := 520
    maxY := 620
    for _, key in HotkeyOrder_Ju {
        if (y > maxY) {
            y := baseY
            x += colWidth
        }
        hk := Hotkeys[key]
        safe := KeyNames[key]
        desc := (Descriptions.HasKey(key) ? " (" . Descriptions[key] . ")" : "")
        label := key . desc
        Gui, 2:Add, Text, x%x% y%y% w320, %label%
        Gui, 2:Add, Edit, x+10 yp w100 v%safe%, %hk%
        y += 28
    }

    ; =========================================================
    ; 🗡 도적 탭 (탭 4)
    ; =========================================================
    Gui, 2:Tab, 4
    Gui, 2:Font, cOrange
    Gui, 2:Add, Text, x40 y80 w700, 🗡 도적 단축키 (오른쪽 단축키설명서를 참고하여 복사붙여넣기 해도됨)
    Gui, 2:Font, cBlack

    baseX := 40, baseY := 120
    x := baseX, y := baseY
    colWidth := 520
    maxY := 620
    for _, key in HotkeyOrder_Thief {
        if (y > maxY) {
            y := baseY
            x += colWidth
        }
        hk := Hotkeys[key]
        safe := KeyNames[key]
        desc := (Descriptions.HasKey(key) ? " (" . Descriptions[key] . ")" : "")
        label := key . desc
        Gui, 2:Add, Text, x%x% y%y% w320, %label%
        Gui, 2:Add, Edit, x+10 yp w100 v%safe%, %hk%
        y += 28
    }

    ; =========================================================
    ; 🛡 전사 탭 (탭 5)
    ; =========================================================
    Gui, 2:Tab, 5
    Gui, 2:Font, cTeal
    Gui, 2:Add, Text, x40 y80 w700, 🛡 전사 단축키 (오른쪽 단축키설명서를 참고하여 복사붙여넣기 해도됨)
    Gui, 2:Font, cBlack

    baseX := 40, baseY := 120
    x := baseX, y := baseY
    colWidth := 520
    maxY := 620
    for _, key in HotkeyOrder_Warrior {
        if (y > maxY) {
            y := baseY
            x += colWidth
        }
        hk := Hotkeys[key]
        safe := KeyNames[key]
        desc := (Descriptions.HasKey(key) ? " (" . Descriptions[key] . ")" : "")
        label := key . desc
        Gui, 2:Add, Text, x%x% y%y% w320, %label%
        Gui, 2:Add, Edit, x+10 yp w100 v%safe%, %hk%
        y += 28
    }

    ; =========================================================
    ; 단축키 설명서 (네 원본 그대로)
    ; =========================================================
    Gui, 2:Tab
    Gui, 2:Font, s10 Bold, Consolas
    Gui, 2:Add, Text, x1220 y55 w260 h20 Center, 🪄 단축키 설명서(직접입력해야함)ㅋ;

    HotkeyGuide =
    (
^           : 컨트롤
+           : 쉬프트
!           : 알트

★컨트롤, 쉬프트, 알트의 응용★
ex) ^s      : 컨트롤+s
ex) !^F1    : 알트+컨트롤+F1

LButton     : 왼쪽 버튼
RButton     : 오른쪽 버튼
MButton     : 중앙 버튼(휠 클릭)
WheelDown   : 휠 아래로 회전
WheelUp     : 휠 위로 회전

XButton1    : 보조 버튼1
XButton2    : 보조 버튼2

a~z, A~Z    : 알파벳, 대소문자 구분
0~9         : 숫자키

Space       : 스페이스
Tab         : 탭
Enter       : 엔터
Esc         : Esc
BS          : 백스페이스
Del         : Del
Ins         : Ins
Home        : Home
End         : End
PgUp        : PgUp
PgDn        : PgDn
Up          : 방향키 위쪽
Down        : 방향키 아래쪽
Left        : 방향키 왼쪽
Right       : 방향키 오른쪽
ScrollLock  : ScrollLock
CapsLock    : CapsLock
NumLock     : NumLock

NumpadDiv   : 숫자 패드의 「/」
NumpadMult  : 숫자 패드의 「*」
NumpadAdd   : 숫자 패드의 「+」
NumpadSub   : 숫자 패드의 「-」
NumpadEnter : 숫자 패드의 「Enter」

아래는 NumLock Off일때
NumpadDel   : 숫자패드 .
NumpadIns   : 숫자패드 0
NumpadClear : 숫자패드 5
NumpadUp    : 숫자패드 8
NumpadDown  : 숫자패드 2
NumpadLeft  : 숫자패드 4
NumpadRight : 숫자패드 6
NumpadHome  : 숫자패드 7
NumpadEnd   : 숫자패드 1
NumpadPgUp  : 숫자패드 9
NumpadPgDn  : 숫자패드 3

아래는 NumLock On일때
Numpad0     : 숫자패드 0
Numpad1     : 숫자패드 1
Numpad2     : 숫자패드 2
Numpad3     : 숫자패드 3
Numpad4     : 숫자패드 4
Numpad5     : 숫자패드 5
Numpad6     : 숫자패드 6
Numpad7     : 숫자패드 7
Numpad8     : 숫자패드 8
Numpad9     : 숫자패드 9
NumpadDot   : 숫자패드 .
    )

    Gui, 2:Font, s9, Consolas
    Gui, 2:Add, Edit, x1220 y80 w260 h720 -Wrap ReadOnly, %HotkeyGuide%

    ; 저장 버튼
    Gui, 2:Add, Button, x640 y760 gSaveHotkeys w120 h35, 저장

    Gui, 2:Show, w1500 h820, 단축키 설정
}

; ------------------------
SaveHotkeys:
    Gui, 2:Default
    Gui, Submit, NoHide
    global Hotkeys, KeyNames, iniFile
    global HotkeysBase, HotkeyOrder_Base
    global HotkeyReverse

    ; ---------- 1) 기본단축키 저장 (BaseHotkeys 섹션) ----------
    for _, _k in HotkeyOrder_Base {
        GuiControlGet, _spell,, HK_BASE_%_k%
        HotkeysBase[_k] := _spell
        if (_spell = "")
            IniDelete, %iniFile%, BaseHotkeys, %_k%
        else
            IniWrite, %_spell%, %iniFile%, BaseHotkeys, %_k%
    }

    ; ---------- 2) 도사/주술 저장 + 역매핑(순수 Numpad만 우선권) 갱신 ----------
    for key, safe in KeyNames {
        GuiControlGet, newHotkey,, %safe%
        oldHot := Hotkeys[key]

        ; 비우기 또는 "없음" 처리
        if (newHotkey = "" or newHotkey = "없음") {
            if (oldHot != "") {
                ; 기존 핫키 해제
                Hotkey, %oldHot%, Off
                ; 역매핑 제거 (이전 값이 순수 Numpad였을 때만)
                oldPure := GetPureNumpadKey(oldHot)
                if (oldPure != "" && HotkeyReverse.HasKey(oldPure))
                    HotkeyReverse.Delete(oldPure)
            }
            Hotkeys[key] := ""
            IniDelete, %iniFile%, Hotkeys, %key%
            continue
        }

        ; 변경된 경우에만 재등록
        if (newHotkey != oldHot) {
            ; 이전 것 해제 + 역매핑 제거
            if (oldHot != "") {
                Hotkey, %oldHot%, Off
                oldPure := GetPureNumpadKey(oldHot)
                if (oldPure != "" && HotkeyReverse.HasKey(oldPure))
                    HotkeyReverse.Delete(oldPure)
            }

            ; 새로 등록
            Hotkeys[key] := newHotkey
            label := key . "_Func"

            Hotkey, IfWinActive, ahk_exe winbaram.exe

            Hotkey, %newHotkey%, %label%

            Hotkey, IfWinActive   ; ★ 해제

            IniWrite, %newHotkey%, %iniFile%, Hotkeys, %key%
            %safe% := newHotkey

            ; 순수 Numpad면 우선권 매핑 추가
            newPure := GetPureNumpadKey(newHotkey)
            if (newPure != "")
                HotkeyReverse[newPure] := label
        } else {
            ; 값이 같아도 역매핑은 보정해 둠 (재실행 후 일관성)
            samePure := GetPureNumpadKey(newHotkey)
            if (samePure != "")
                HotkeyReverse[samePure] := key . "_Func"
        }
    }

    MsgBox, 4096, 저장 완료, 핫키 설정이 저장 및 적용되었습니다.
return



BaseNumberHotkey(key, physicalKey) {
    global HotkeysBase, ChatMode, HotkeyReverse

    ; 1) 채팅 모드: 키 그대로 출력
    if (ChatMode) {
        if InStr(physicalKey, "Numpad")
            SendInput % "{" physicalKey "}"
        else
            SendInput % physicalKey
        return
    }

    ; 2) 도/주술 우선권: "오직 순수 NumpadX"에만 적용
    if (InStr(physicalKey, "Numpad")) {
        if (HotkeyReverse.HasKey(physicalKey)) {
            Gosub, % HotkeyReverse[physicalKey]
            return
        }
    }

    ; 3) 그 외엔 기본키(숫자행 포함) 실행
    spell := HotkeysBase[key]
    if (spell != "")
        마법(spell)
}


2GuiClose:
    Gui, 2:Hide
return

; 버튼 눌렀을 때 실행되는 함수
OpenHotkeyGui:
    CreateGui2()
return


CreateCooldownGUI() {
    global CoolSpells, LabelHeader
    global Cool1, Cool2, Cool3, Cool4, Cool5, Cool6, Cool7, Cool8, Cool9, Cool10
    global Cool11, Cool12, Cool13, Cool14, Cool15

    CoolSpells := []   ; ✅ 딕셔너리({}) 대신 배열([]) 사용

    Gui, Cool:Destroy
    ;-----------------------------------------
    ; 🧊 완전 투명 배경 + 글자만 표시
    Gui, Cool:+AlwaysOnTop +ToolWindow -Caption +LastFound
    Gui, Cool:Color, 0x010101        ; 임의의 투명 처리용 색
    WinSet, TransColor, 0x010101     ; 👈 이 색을 완전 투명하게 처리
    Gui, Cool:Font, s11 bold, Malgun Gothic
    ;-----------------------------------------

    Gui, Cool:Add, Text, vLabelHeader w220 h25 Center cLime, 🔹 스킬 쿨타임 🔹
    Loop, 15
        Gui, Cool:Add, Text, vCool%A_Index% w220 h22 Center cWhite,

    ; 기본 위치 (원하면 조정 가능)
    Gui, Cool:Show, x0 y150 NoActivate, CoolTime
    Gui, Cool:Default

    ; 드래그 이동 가능
    OnMessage(0x201, "WM_LBUTTONDOWN")

    ; 쿨타임 갱신 타이머
    SetTimer, UpdateAllCoolTimes, 1000
}

;========================================
; 🧊 쿨타임 추가 함수
;========================================
ShowCooldown(spellName, durationSec) {
    global CoolSpells
    ; ✅ 같은 스킬이 이미 있으면 제거 후 다시 추가
    Loop % CoolSpells.Length() {
        if (CoolSpells[A_Index].name = spellName) {
            CoolSpells.RemoveAt(A_Index)
            break
        }
    }
    CoolSpells.Push({name: spellName, remain: durationSec})  ; ✅ 순서 유지
    UpdateCooldownGUI()
}

;========================================
; 🔁 매초 전체 갱신 타이머
;========================================
UpdateAllCoolTimes:
    global CoolSpells, MainWindowTitle
    TooltipX := 200
    TooltipY := 160

    Loop % CoolSpells.Length() {
        i := A_Index
        CoolSpells[i].remain--

        if (CoolSpells[i].remain <= 0) {
            spell := CoolSpells[i].name
            CoolSpells.RemoveAt(i)
            ;SoundBeep, 1200
            ToolTip, ✅ %spell% 사용 가능!, %TooltipX%, %TooltipY%
            SetTimer, ToolTipOff, -1500
            break  ; 배열 길이 변했으니 break 후 재실행됨
        }
    }
    UpdateCooldownGUI()
return

;========================================
; 🖥️ GUI 갱신 함수 (깜빡임 없음)
;========================================
UpdateCooldownGUI() {
    global CoolSpells
    global Cool1, Cool2, Cool3, Cool4, Cool5, Cool6, Cool7, Cool8, Cool9, Cool10
    global Cool11, Cool12, Cool13, Cool14, Cool15

    Gui, Cool:Default
    index := 1
    spellCount := 0

    for i, data in CoolSpells {
        spellCount++
        remain := data.remain
        if (remain < 0)
            remain := 0
        GuiControl,, Cool%index%, % data.name " : " remain "s"
        index++
    }

    ; 남은 줄 비우기
    Loop, 15 {
        if (A_Index >= index)
            GuiControl,, Cool%A_Index%,
    }

    if (spellCount = 0)
        GuiControl,, Cool1, (현재 쿨타임 없음)
}

;========================================
; 💬 툴팁 닫기
;========================================
ToolTipOff:
ToolTip
return

;========================================
; 🖱️ 드래그 이동 처리
;========================================
WM_LBUTTONDOWN() {
    PostMessage, 0xA1, 2,,, A
}


$1::BaseNumberHotkey("1", "1")
$2::BaseNumberHotkey("2", "2")
$3::BaseNumberHotkey("3", "3")
$4::BaseNumberHotkey("4", "4")
$5::BaseNumberHotkey("5", "5")
$6::BaseNumberHotkey("6", "6")
$7::BaseNumberHotkey("7", "7")
$8::BaseNumberHotkey("8", "8")
$9::BaseNumberHotkey("9", "9")
$0::BaseNumberHotkey("0", "0")

$Numpad1::BaseNumberHotkey("1", "Numpad1")
$Numpad2::BaseNumberHotkey("2", "Numpad2")
$Numpad3::BaseNumberHotkey("3", "Numpad3")
$Numpad4::BaseNumberHotkey("4", "Numpad4")
$Numpad5::BaseNumberHotkey("5", "Numpad5")
$Numpad6::BaseNumberHotkey("6", "Numpad6")
$Numpad7::BaseNumberHotkey("7", "Numpad7")
$Numpad8::BaseNumberHotkey("8", "Numpad8")
$Numpad9::BaseNumberHotkey("9", "Numpad9")
$Numpad0::BaseNumberHotkey("0", "Numpad0")

#IfWinActive


;}

;#GUI 등록마법키
;{

자힐.도_Func:
    Gosub, 자힐
return

자힐.주_Func:
    Gosub, 자힐
return

보무.도_Func:
    Gosub, 자신보무
return

보무.주_Func:
    Gosub, 자신보무
return

현재시간.도_Func:
    Gosub, 현재시간
return

현재시간.주_Func:
    Gosub, 현재시간
return

현재시간.전_Func:
    Gosub, 현재시간
return

현재시간.적_Func:
    Gosub, 현재시간
return


마성_Func:
    Gosub, 마성
return

마저성_Func:
    Gosub, 마저성
return

마저_Func:
    Gosub, 마저
return

마중_Func:
    Gosub, 마중
return

마절_Func:
    Gosub, 마절
return

마마_Func:
    Gosub, 마마
return

Toggle순환_Func:
    Gosub, Toggle순환
return

마백파_Func:
    Gosub, 마백파
return

마봘_Func:
    Gosub, 마봘
return

Toggle혼마술_Func:
    Gosub, Toggle혼마술
return

환군_Func:
    Gosub, 환군
return

파력무참_Func:
    Gosub, 파력무참
return

귀염_Func:
    Gosub, 귀염
return

마혼_Func:
    Gosub, 마혼
return

마혼진_Func:
    Gosub, 마혼진
return

마도탈_Func:
    Gosub, 마도탈
return

마주탈_Func:
    Gosub, 마주탈
return

마적탈_Func:
    Gosub, 마적탈
return

마전탈_Func:
    Gosub, 마전탈
return

마공_Func:
    Gosub, 마공
return

자삼매_Func:
    Gosub, 자삼매
return

지폭지술_Func:
    Gosub, 지폭지술
return

폭류유성_Func:
    Gosub, 폭류유성
return

만파지독_Func:
    Gosub, 만파지독
return

마기호체_Func:
    Gosub, 마기호체
return

Toggle절망_Func:
    Gosub, Toggle절망
return

Toggle마비_Func:
    Gosub, Toggle마비
return

Toggle저주_Func:
    Gosub, Toggle저주
return

Toggle중독_Func:
    Gosub, Toggle중독
return

Toggle다운성려_Func:
    Gosub, Toggle다운성려
return

Toggle업성려_Func:
    Gosub, Toggle업성려
return

딜파력_Func:
    Gosub, 딜파력
return

딜환군_Func:
    Gosub, 딜환군
return

딜귀염_Func:
    Gosub, 딜귀염
return

딜백호첨_Func:
    Gosub, 딜백호첨
return

딜백호_Func:
    Gosub, 딜백호
return

딜헬파_Func:
    Gosub, 딜헬파
return

딜삼매_Func:
    Gosub, 딜삼매
return

딜지폭_Func:
    Gosub, 딜지폭
return

딜폭류_Func:
    Gosub, 딜폭류
return

딜마기_Func:
    Gosub, 딜마기
return

딜탈명지_Func:
    Gosub, 딜탈명지
return

딜탈명염_Func:
    Gosub, 딜탈명염
return

딜탈명풍_Func:
    Gosub, 딜탈명풍
return

딜탈명뇌_Func:
    Gosub, 딜탈명뇌
return

선풍각.주_Func:
    Gosub, 선풍각
return

선풍각.도_Func:
    Gosub, 선풍각
return

선풍각.전_Func:
    Gosub, 선풍각
return

전혈_Func:
    Gosub, 전혈
return

분혼경천_Func:
    Gosub, 분혼경천
return

혈겁만파_Func:
    Gosub, 혈겁만파
return

포효검황_Func:
    Gosub, 포효검황
return

진백호령_Func:
    Gosub, 진백호령
return

어검술_Func:
    Gosub, 어검술
return

쇄혼비무_Func:
    Gosub, 쇄혼비무
return

초혼비무_Func:
    Gosub, 초혼비무
return

극백호참_Func:
    Gosub, 극백호참
return

무영검_Func:
    Gosub, 무영검
return

무형검_Func:
    Gosub, 무형검
return

이기어검_Func:
    Gosub, 이기어검
return

파천검무_Func:
    Gosub, 파천검무
return

딜전혈_Func:
    Gosub, 딜전혈
return

딜무영검_Func:
    Gosub, 딜무영검
return

딜분혼_Func:
    Gosub, 딜분혼
return

딜초혼_Func:
    Gosub, 딜초혼
return

딜쇄혼_Func:
    Gosub, 딜쇄혼
return

딜어검_Func:
    Gosub, 딜어검
return

딜칼_Func:
    Gosub, 딜칼
return

딜뿡_Func:
    Gosub, 딜뿡
return

딜진백_Func:
    Gosub, 딜진백
return

딜극백_Func:
    Gosub, 딜극백
return


;}

;#함수 및 레이블
;{

선풍각:
마법클릭엔터("오성선풍각")
return

딜파력:
sendinput, '/딜 파력무참{enter}
return

딜환군:
sendinput, '/딜 환군마술{enter}
return

딜귀염:
sendinput, '/딜 귀염추혼소{enter}
return

딜백호첨:
sendinput, '/딜 백호의희원'첨{enter}
return

딜백호:
sendinput, '/딜 백호의희원{enter}
return

딜헬파:
sendinput, '/딜 헬파이어{enter}
return

딜삼매:
sendinput, '/딜 삼매진화{enter}
return

딜지폭:
sendinput, '/딜 지폭지술{enter}
return

딜폭류:
sendinput, '/딜 폭류유성{enter}
return

딜마기:
sendinput, '/딜 마기지체{enter}
return

딜만파:
sendinput, '/딜 만파지독{enter}
return

딜탈명지:
sendinput, '/딜 탈명사식'지{enter}
return

딜탈명염:
sendinput, '/딜 탈명사식'염{enter}
return

딜탈명풍:
sendinput, '/딜 탈명사식'풍{enter}
return

딜탈명뇌:
sendinput, '/딜 탈명사식'뇌{enter}
return

딜초혼:
sendinput, '/딜 초혼비무{enter}
return

딜쇄혼:
sendinput, '/딜 쇄혼비무{enter}
return

딜어검:
sendinput, '/딜 어검술{enter}
return

딜칼:
sendinput, '/딜 혈겁만파{enter}
return

딜뿡:
sendinput, '/딜 포효검황{enter}
return

딜진백:
sendinput, '/딜 진백호령{enter}
return

딜극백:
sendinput, '/딜 극백호참{enter}
return

딜전혈:
sendinput, '/딜 전혈{enter}
return

딜무영검:
sendinput, '/딜 무영검{enter}
return

딜분혼:
sendinput, '/딜 분혼경천{enter}
return

현재시간:
sendinput, '/현재시간{Enter}
return

Toggle혼마술:

Toggle혼마술 := !Toggle혼마술
Toggle순환 := false

if (Toggle혼마술) {
    SetTimer, 순첨, Off
    ToolTip
    SetTimer, 혼, 10
    GuiControl,, 작동마법, 💥 혼마술ing...ㅋ;
} else {
    SetTimer, 혼, Off
    GuiControl,, 작동마법, 💥 대기중...ㅋ;
}
return

Toggle순환:

Toggle순환 := !Toggle순환
Toggle혼마술 := false

if (Toggle순환) {
    SetTimer, 혼, Off
    ToolTip
    SetTimer, 순첨, 10
    GuiControl,, 작동마법, 💥 순환ing...ㅋ;
} else {
    SetTimer, 순첨, Off
    GuiControl,, 작동마법, 💥 대기중...ㅋ;
}
return

자힐:
    자힐()
return

자신보무:
    마법홈엔터("보호")
    마법홈엔터("무장")
    sendinput, :d
return

귀염:

; ✅ 현재 toggle 상태 저장
wasToggle순환 := toggle순환

; ✅ 기능 모두 일시 정지
if (wasToggle순환) {
    SetTimer, 순첨, Off
    ToolTip
}
sleep,300

    마법("귀염추혼소")
    ShowCooldown("귀염추혼소", 29)

; ✅ 기존 toggle 상태에 따라 기능 재개
if (wasToggle순환) {
    SetTimer, 순첨, 10
}

sleep, 50
return

파력무참:

; ✅ 현재 toggle 상태 저장
wasToggle순환 := toggle순환

; ✅ 기능 모두 일시 정지
if (wasToggle순환) {
    SetTimer, 순첨, Off
    ToolTip
}
sleep,300

    마법("귀염추혼소")
    sleep, 50
    마법("파력무참")
    ShowCooldown("파력무참", 179)
    ShowCooldown("귀염추혼소", 29)

; ✅ 기존 toggle 상태에 따라 기능 재개
if (wasToggle순환) {
    SetTimer, 순첨, 10
}

sleep, 50
return

환군:
    마법("환군마술")
    ShowCooldown("환군마술", 599)
return

마백파:
    마법클릭엔터("백호의희원")
    마법엔터("파혼술")
return

마도탈:
    마법클릭엔터("탈명사식'풍")
    마법("만공")
    ShowCooldown("탈명사식'풍", 149)
return

마주탈:
    마법클릭엔터("탈명사식'지")
    마법("만공")
    ShowCooldown("탈명사식'지", 149)
return

마적탈:
    마법클릭엔터("탈명사식'뇌")
    ShowCooldown("탈명사식'뇌", 149)
return

마전탈:
    마법클릭엔터("탈명사식'염")
    ShowCooldown("탈명사식'염", 149)
return

마공:
    마법클릭엔터("공력주입")
    마법("만공")
return

마혼:
    마법클릭엔터("혼마술")
return

마혼진:
    마법클릭엔터("혼마술")
    마법클릭엔터("지진")
return

마봘:
    마법클릭엔터("부활")
    마법엔터("백호의희원")
return

순첨:
    Loop,10 {
        마법("순환")
        sleep, 30
    }
    마법("백호의희원'첨")
    sleep, 30
    마법("금강불체")
    sleep, 30
    공증3()
return

혼()
{
    마법업엔터("혼마술")
    sleep, 30
}

Toggle업성려:

toggle업성려 := !toggle업성려  ; 토글 상태 반전
Toggle다운성려 := false
Toggle중독 := false
Toggle저주 := false
Toggle마비 := false
Toggle절망 := false

if (toggle업성려) {
    SetTimer, Down성려, Off
    SetTimer, 중독, Off
    SetTimer, 저주, Off
    SetTimer, 마비, Off
    SetTimer, 절망, Off
    SetTimer, Up성려, 10
    GuiControl,, 작동마법, 💥 Up성려ing...ㅋ;
} else {
    SetTimer, Up성려, Off
    GuiControl,, 작동마법, 💥 대기중...ㅋ;
}

return

Toggle다운성려:

toggle다운성려 := !toggle다운성려  ; 토글 상태 반전
Toggle업성려 := false
Toggle중독성려 := false
Toggle저주 := false
Toggle마비 := false
Toggle절망 := false

if (toggle다운성려) {
    SetTimer, Up성려, Off
    SetTimer, 중독, Off
    SetTimer, 저주, Off
    SetTimer, 마비, Off
    SetTimer, 절망, Off
    SetTimer, Down성려, 10
    GuiControl,, 작동마법, 💥 Down성려ing...ㅋ;
} else {
    SetTimer, Down성려, Off
    GuiControl,, 작동마법, 💥 대기중...ㅋ;
}

return

Toggle중독:

toggle중독 := !toggle중독  ; 토글 상태 반전
Toggle업성려 := false
Toggle다운성려 := false
Toggle저주 := false
Toggle마비 := false
Toggle절망 := false

if (toggle중독) {
    SetTimer, Up성려, Off
    SetTimer, Down성려, Off
    SetTimer, 저주, Off
    SetTimer, 마비, Off
    SetTimer, 절망, Off
    SetTimer, 중독, 10
    GuiControl,, 작동마법, 💥 중독ing...ㅋ;
} else {
    SetTimer, 중독, Off
    GuiControl,, 작동마법, 💥 대기중...ㅋ;
}

return

Toggle저주:

toggle저주 := !toggle저주  ; 토글 상태 반전
Toggle업성려 := false
Toggle다운성려 := false
Toggle중독 := false
Toggle마비 := false
Toggle절망 := false

if (toggle저주) {
    SetTimer, Up성려, Off
    SetTimer, Down성려, Off
    SetTimer, 중독, Off
    SetTimer, 마비, Off
    SetTimer, 절망, Off
    SetTimer, 저주, 10
    GuiControl,, 작동마법, 💥 저주ing...ㅋ;
} else {
    SetTimer, 저주, Off
    GuiControl,, 작동마법, 💥 대기중...ㅋ;
}

return

Toggle마비:

toggle마비 := !toggle마비  ; 토글 상태 반전
Toggle업성려 := false
Toggle다운성려 := false
Toggle중독 := false
Toggle저주 := false
Toggle절망 := false

if (toggle마비) {
    SetTimer, Up성려, Off
    SetTimer, Down성려, Off
    SetTimer, 중독, Off
    SetTimer, 저주, Off
    SetTimer, 절망, Off
    SetTimer, 마비, 10
    GuiControl,, 작동마법, 💥 마비ing...ㅋ;
} else {
    SetTimer, 마비, Off
    GuiControl,, 작동마법, 💥 대기중...ㅋ;
}

return

Toggle절망:

toggle절망 := !toggle절망  ; 토글 상태 반전
Toggle업성려 := false
Toggle다운성려 := false
Toggle중독 := false
Toggle저주 := false
Toggle마비 := false

if (toggle절망) {
    SetTimer, Up성려, Off
    SetTimer, Down성려, Off
    SetTimer, 중독, Off
    SetTimer, 저주, Off
    SetTimer, 마비, Off
    SetTimer, 절망, 10
    GuiControl,, 작동마법, 💥 절망ing...ㅋ;
} else {
    SetTimer, 절망, Off
    GuiControl,, 작동마법, 💥 대기중...ㅋ;
}

return

마저성:
    마법클릭엔터("저주")
    마법엔터("성려멸주")
    공증8()
return

마성:
    마법클릭엔터("성려멸주")
    공증8()
return

마저:
    마법클릭엔터("저주")
return

마중:
    마법클릭엔터("중독")
return

마절:
    마법클릭엔터("절망")
return

마마:
    마법클릭엔터("마비")
return



마기호체:
    sleep, 100
    마법("호체주술")
    sleep, 100
    마법("마기지체")
    ShowCooldown("마기지체", 218)
    ShowCooldown("호체주술", 231)
return

지폭지술:
    sleep, 100
    마법("지폭지술")
    마법("만공")
    ShowCooldown("지폭지술", 225)

return

폭류유성:
    sleep, 100
    마법("폭류유성")
    마법("만공")
    ShowCooldown("폭류유성", 359)
return

만파지독:
    sleep, 100
    마법("만파지독")
    ShowCooldown("만파지독", 59)
return


자삼매:
    마법홈엔터("삼매진화")
    ShowCooldown("삼매진화", 29)
return

중독()
{
    마법업엔터("중독")
    sleep, 30
}

저주()
{
    마법업엔터("저주")
    sleep, 30
}

마비()
{
    마법업엔터("마비")
    sleep, 30
}

절망()
{
    마법업엔터("절망")
    sleep, 30
}


Up성려()
{
    마법홈업엔터("성려멸주")
    sleep, 30
    공증8()
}

Down성려()
{
    마법홈다운엔터("성려멸주")
    sleep, 30
    공증8()
}

CheckMPDrink()
{
    global MainWindowTitle
    global 첨자동ON, 첨자동잠시정지

    wasRunning := false
    if (첨자동ON) {
        첨자동잠시정지 := true
        wasRunning := true
    }

    baseAddr := ReadMemory(0x0055DB04, MainWindowTitle)
    if baseAddr = "Read Failed"
        goto Done

    mp := ReadMPData(baseAddr, MainWindowTitle)
    if !IsObject(mp)
        goto Done

    if (mp.NowMP <= mp.FullMP * 0.01)
    {
        Loop
        {
            mp := ReadMPData(baseAddr, MainWindowTitle)
            if !IsObject(mp)
                break

            if (mp.NowMP >= mp.FullMP)
                break

            if (mp.NowMP < 30)
            {
                slot := GetDrink()
                if (slot)
                {
                    UseDrink(slot)
                    Sleep, 100
                }
                else
                {
                    ToolTip, 술 없음! 인벤 확인 필요
                    SetTimer, RemoveTip, -1500
                    break
                }
            }
            else
            {
                마법("공력증강")
                Sleep, 100
            }
        }
    }
Done:
    if (wasRunning)
        첨자동잠시정지 := false
}

자동공증()     ; 주술사 자동공증
{
    if !WinActive("ahk_exe winbaram.exe")
        return

    CheckMPDrink()  ; MP 확인해서 0이면 술 사용 + 공증
}


Toggle심투:

    global toggle심투
    toggle심투 := !toggle심투  ; 토글 상태 반전

    if (toggle심투) {
        SetTimer, main, 100
        GuiControl,, Btn심투, ✅ 심투 ON
		WinActivate, ahk_exe winbaram.exe
        msgbox, 핵쟁이씨발새끼 ㅋ;
    } else {
        SetTimer, main, Off
        GuiControl,, Btn심투, 🔘 심투 OFF
		WinActivate, ahk_exe winbaram.exe
    }

return

Toggle공증:
    global toggle공증
    toggle공증 := !toggle공증  ; 토글 상태 반전

    if (toggle공증) {
        SetTimer, 자동공증, 100
        GuiControl,, Btn공증, ✅ 공증 ON
		WinActivate, ahk_exe winbaram.exe
        msgbox, 공성할땐 안쓰는게좋을꺼얔;ㅋ;
    } else {
        SetTimer, 자동공증, Off
        GuiControl,, Btn공증, 🔘 공증 OFF
		WinActivate, ahk_exe winbaram.exe
    }

return

전혈:
    마법("전혈")
    ShowCooldown("전혈", 59)
return

분혼경천:
    마법("분혼경천")
    ShowCooldown("분혼경천", 165)
return

혈겁만파:
    마법("혈겁만파")
    ShowCooldown("혈겁만파", 272)
return

포효검황:
    마법("포효검황")
    ShowCooldown("포효검황", 165)
return

진백호령:
    마법("진백호령")
    ShowCooldown("진백호령", 59)
return

어검술:
    마법("어검술")
    ShowCooldown("어검술", 19)
return

쇄혼비무:
    마법("쇄혼비무")
    ShowCooldown("쇄혼비무", 19)
return

초혼비무:
    마법("초혼비무")
    ShowCooldown("초혼비무", 19)
return

극백호참:
    마법("극백호참")
    ShowCooldown("극백호참", 59)
return

무영검:
    마법("무영검")
    ShowCooldown("무영검", 59)
return

무형검:
    마법("무형검")
    ShowCooldown("무형검", 29)
return

이기어검:
    마법("이기어검")
    ShowCooldown("이기어검", 29)
return

파천검무:
    마법("파천검무")
    ShowCooldown("파천검무", 15)
return










GuiClose:
GuiEscape:
    SetTimer, 자동공증, Off
    SetTimer, main, Off
	공증ON := false, 심투ON := false
    GuiControl, 1:, Btn공증, 🔘 공증 OFF
    GuiControl, 1:, Btn심투, 🔘 심투 OFF
    Gui, 1:Destroy
    ExitApp
return

FocusBackToGame:
    WinActivate, ahk_exe winbaram.exe
return


RemoveTip:
    ToolTip
return

;}

;#경험치계산
;{

ExpGUI_StartExpCalc:
    base := ReadMemory(0x0055DB04, MainWindowTitle)
    if (base = "Read Failed")
        return

    global LastExp := ReadMemory(base + 0x120, MainWindowTitle)
    global TotalGain := 0
    StartTime := A_TickCount

    SetTimer, ExpCalc, 1000
    WinActivate, ahk_exe winbaram.exe
return

ExpCalc:
    base := ReadMemory(0x0055DB04, MainWindowTitle)
    if (base = "Read Failed") {
        GuiControl, 2:, ExpCalc, 게임을 찾을 수 없음
        return
    }
    ExpNow := ReadMemory(base + 0x120, MainWindowTitle)
    if (ExpNow = "Process Doesn't Exist") {
        GuiControl, 2:, ExpCalc, 게임 프로세스 없음
        return
    }
    if (LastExp = 0)
        LastExp := ExpNow

    if (ExpNow > LastExp) {
        TotalGain += (ExpNow - LastExp)
    }

    LastExp := ExpNow

    NowExp := TotalGain / 100000000
    elapsed := (A_TickCount - StartTime) / 1000
    hours := Floor(elapsed / 3600)
    mins := Floor(Mod(elapsed, 3600) / 60)
    secs := Mod(elapsed, 60)

    if (elapsed > 0)
        ExpPerHour := (NowExp / (elapsed / 3600))
    else
        ExpPerHour := 0

    GuiControl, 1:, ExpCalc, % "시간당 경험치 : " Format("{:.2f}", ExpPerHour) "억"
    GuiControl, 1:, HuntingTime, % "사냥시간 : " hours "시간 " mins "분 " secs "초"
    GuiControl, 1:, GetExp1, % "획득 경험치 : " Format("{:.2f}", NowExp) "억"
return

ExpGUI_StopExpCalc:
    SetTimer, ExpCalc, Off

    NowExp := TotalGain / 100000000
    elapsed := (A_TickCount - StartTime) / 1000
    hours := Floor(elapsed / 3600)
    mins := Floor(Mod(elapsed, 3600) / 60)
    secs := Mod(elapsed, 60)

    if (elapsed > 0)
        ExpPerHour := (NowExp / (elapsed / 3600))
    else
        ExpPerHour := 0

    FormatTime, now,, yyyy-MM-dd HH:mm:ss

    expText := "획득 경험치 : " Format("{:.2f}", NowExp) "억"
    timeText := "사냥 시간     : " hours "시간 " mins "분 " secs "초"
    perHourText := "시간당 경험치 : " Format("{:.2f}", ExpPerHour) "억"

    log =
    (
[%now%]
%expText%
%timeText%
%perHourText%
-----------------------------------
    )

    FileAppend, %log%`n, 경험치로그.txt, UTF-8
    WinActivate, ahk_exe winbaram.exe
    msgbox, 오핫폴더안에 경험치로그 메모장확인해봐ㅋ;
return

;}

;#아이템사용함수
;{

UseDrink(Num)    ;아이템 찾아서 먹기(e) 명령어
{

   PostMessage, 0x100, 69,3014657,,%MainWindowTitle%

   if(Num <= 26)
   {
      Param := 64 + Num
      PostMessage, 0x100,%Param%,,,%MainWindowTitle%
      PostMessage, 0x100, 27,65537,,%MainWindowTitle%
   }
   else
   {
      Num -= 26
      Param := 64 + Num
      PostMessage, 0x100, 16,2752513,,%MainWindowTitle%
      PostMessage, 0x100,%Param%,,,%MainWindowTitle%
      PostMessage, 0x101, 16,2752513,,%MainWindowTitle%
      PostMessage, 0x100, 27,65537,,%MainWindowTitle%

   }
}

Usecho(Num)   ;아이템 찾아서 사용(u) 명령어
{

   PostMessage, 0x100, 85,3014657,,%MainWindowTitle%

   if(Num <= 26)
   {
      Param := 64 + Num
      PostMessage, 0x100,%Param%,,,%MainWindowTitle%
      PostMessage, 0x100, 27,65537,,%MainWindowTitle%
   }
   else
   {
      Num -= 26
      Param := 64 + Num
      PostMessage, 0x100, 16,2752513,,%MainWindowTitle%
      PostMessage, 0x100,%Param%,,,%MainWindowTitle%
      PostMessage, 0x101, 16,2752513,,%MainWindowTitle%
      PostMessage, 0x100, 27,65537,,%MainWindowTitle%

   }
}


UseItem(Num)     ;아이템 찾는 함수 w로 사용되게함
{
	static MainEquipTime
	if(MainEquipTime + 1 < A_TickCount)
	{
	PostMessage, 0x100, 87,1114113,,%MainWindowTitle%

	if(Num <= 26)
	{
		Param := 64 + Num
		PostMessage, 0x100,%Param%,,,%MainWindowTitle%
		PostMessage, 0x100, 27,65537,,%MainWindowTitle%
	}
	else
	{
		Num -= 26
		Param := 64 + Num
		PostMessage, 0x100, 16,2752513,,%MainWindowTitle%
		PostMessage, 0x100,%Param%,,,%MainWindowTitle%
		PostMessage, 0x101, 16,2752513,,%MainWindowTitle%
		PostMessage, 0x100, 27,65537,,%MainWindowTitle%

	}
		MainEquipTime := A_TickCount
	}
}

; 술 찾고 자동 사용
GetDrink()   ; 술 찾기 → 슬롯 번호(1~52) 반환, 없으면 0
{
    loop, 52
    {
        Offset := 0x206 + ((A_Index - 1) * 0xB0)
        DrinkName := ReadMemoryTxt2( ReadMemory(0x0055D4F8, MainWindowTitle) + Offset
                                   , MainWindowTitle )

        if (DrinkName != ""                         ; 빈칸 아니고
            &&  ( InStr(DrinkName,"동동주")         ; 원하는 술 이름인지?
               || InStr(DrinkName,"막걸리")
               || InStr(DrinkName,"탁주")
               || InStr(DrinkName,"감자주")
               || InStr(DrinkName,"오십세주")
               || InStr(DrinkName,"팔십세주")
               || InStr(DrinkName,"백세주")
               || InStr(DrinkName,"이백세주")
               || InStr(DrinkName,"삼백세주")
               || InStr(DrinkName,"오백세주") ))
        {
            return A_Index          ; 찾자마자 슬롯 번호 돌려주기
        }
    }
    return 0                        ; 못 찾음
}

;}

;#메모리관련
;{

ConvertBase(InputBase, OutputBase, number)
{
  static u := A_IsUnicode ? "_wcstoui64" : "_strtoui64"
  static v := A_IsUnicode ? "_i64tow"    : "_i64toa"
  VarSetCapacity(s, 65, 0)
  value := DllCall("msvcrt.dll\" u, "Str", number, "UInt", 0, "UInt", InputBase, "CDECL Int64")
  DllCall("msvcrt.dll\" v, "Int64", value, "Str", s, "UInt", OutputBase, "CDECL")
  return s
}
WriteMemory(WriteAddress = "", PROGRAM="", Data="", TypeOrLength = "")
{
   Static OLDPROC, hProcess, pid
   If (PROGRAM != OLDPROC)
   {
        if hProcess
          closed := DllCall("CloseHandle", "UInt", hProcess), hProcess := 0, OLDPROC := ""
        if PROGRAM
        {
            WinGet, pid, pid, % OLDPROC := PROGRAM
            jPID = pid
            if !pid
               return "Process Doesn't Exist", OLDPROC := "" ;blank OLDPROC so subsequent calls will work if process does exist
            hProcess := DllCall("OpenProcess", "Int", 0x8 | 0x20, "Int", 0, "UInt", pid)
        }
   }
    If Data is Number   ; Either a numeric value or a memory address.
    {
        If TypeOrLength is Integer  ; Address of a buffer was passed.
        {
            DataAddress := Data
            DataSize := TypeOrLength    ; Length in bytes of the data in the buffer.
        }
        Else    ; A numeric value was passed.
        {
            If (TypeOrLength = "Double" or TypeOrLength = "Int64")
                DataSize = 8
            Else If (TypeOrLength = "Int" or TypeOrLength = "UInt"
                                          or TypeOrLength = "Float")
                DataSize = 4
            Else If (TypeOrLength = "Short" or TypeOrLength = "UShort")
                DataSize = 2
            Else If (TypeOrLength = "Char" or TypeOrLength = "UChar")
       DataSize = 1
            Else {
              ;  MsgBox, Invalid type of number.
                Return False
            }
            VarSetCapacity(Buf, DataSize, 0)
            NumPut(Data, Buf, 0, TypeOrLength)
            DataAddress := &Buf
        }
    }
    Else    ; Data is a string.
    {
        DataAddress := &Data
        If TypeOrLength is Integer  ; Length (in characters) was specified.
        {
            If A_IsUnicode
                DataSize := TypeOrLength * 2    ; 1 character = 2 bytes.
            Else
                DataSize := TypeOrLength
        }
        Else
        {
            If A_IsUnicode
                DataSize := (StrLen(Data) + 1) * 2  ; Take the whole string
            Else                                    ; with the null terminator.
                DataSize := StrLen(Data) + 1
        }
    }
    ; will return null if write works
    if (hProcess && DllCall("WriteProcessMemory", "UInt", hProcess
                                         , "UInt", WriteAddress
                                         , "UInt", DataAddress
                                         , "UInt", DataSize
                                         , "UInt", 0))
        return
    else  return !hProcess ? "Handle Closed:" closed : "Fail"
}
ReadMemoryTxt(MADDRESS,PROGRAM)
{
	winget, pid, PID, %PROGRAM%
	VarSetCapacity(MVALUE,15,0)
	ProcessHandle := DllCall("OpenProcess", "Int", 24, "Char", 0, "UInt", pid, "UInt")
	DllCall("ReadProcessMemory","UInt",ProcessHandle,"UInt",MADDRESS,"Str",MVALUE,"UInt",15,"UInt *",0)
	return MVALUE
}
ReadMemoryTxt2(MADDRESS,PROGRAM)
{
	winget, pid, PID, %PROGRAM%
	VarSetCapacity(MVALUE,20,0)
	ProcessHandle := DllCall("OpenProcess", "Int", 24, "Char", 0, "UInt", pid, "UInt")
	DllCall("ReadProcessMemory","UInt",ProcessHandle,"UInt",MADDRESS,"Str",MVALUE,"UInt",20,"UInt *",0)
	return MVALUE
}
ReadMemory(MADDRESS=0,PROGRAM="",BYTES=4)
{
   Static OLDPROC, ProcessHandle
   VarSetCapacity(buffer, BYTES)
   If (PROGRAM != OLDPROC)
   {
        if ProcessHandle
          closed := DllCall("CloseHandle", "UInt", ProcessHandle), ProcessHandle := 0, OLDPROC := ""
        if PROGRAM
        {
            WinGet, pid, pid, % OLDPROC := PROGRAM
            if !pid
               return "Process Doesn't Exist", OLDPROC := ""
            ProcessHandle := DllCall("OpenProcess", "Int", 16, "Int", 0, "UInt", pid)
        }
   }
   If !(ProcessHandle && DllCall("ReadProcessMemory", "UInt", ProcessHandle, "UInt", MADDRESS, "Ptr", &buffer, "UInt", BYTES, "Ptr", 0))
      return !ProcessHandle ? "Handle Closed: " closed : "Fail"
   else if (BYTES = 1)
      Type := "UChar"
   else if (BYTES = 2)
      Type := "UShort"
   else if (BYTES = 4)
      Type := "UInt"
   else
      Type := "Int64"
   return numget(buffer, 0, Type)
}

ReadMPData(baseAddr, PROGRAM)
{
   static ProcessHandle := 0, LastPID := 0
   WinGet, pid, PID, %PROGRAM%
   if (!pid)
       return "Process Not Found"

   if (pid != LastPID || !ProcessHandle) {
       if (ProcessHandle)
           DllCall("CloseHandle", "UInt", ProcessHandle)
       ProcessHandle := DllCall("OpenProcess", "UInt", 0x10, "Int", 0, "UInt", pid, "UInt")
       if !ProcessHandle
           return "OpenProcess Failed"
       LastPID := pid
   }

   VarSetCapacity(buffer, 0x120, 0)
   success := DllCall("ReadProcessMemory", "UInt", ProcessHandle, "UInt", baseAddr, "Ptr", &buffer, "UInt", 0x120, "Ptr", 0)
   if !success
       return "Read Failed"

   NowMP := NumGet(buffer, 0x118, "UInt")
   FullMP := NumGet(buffer, 0x11C, "UInt")
   return { "NowMP": NowMP, "FullMP": FullMP }
}

ReadHPData(baseAddr, PROGRAM)
{
   static ProcessHandle := 0, LastPID := 0
   WinGet, pid, PID, %PROGRAM%
   if (!pid)
       return "Process Not Found"

   if (pid != LastPID || !ProcessHandle) {
       if (ProcessHandle)
           DllCall("CloseHandle", "UInt", ProcessHandle)
       ProcessHandle := DllCall("OpenProcess", "UInt", 0x10, "Int", 0, "UInt", pid, "UInt")
       if !ProcessHandle
           return "OpenProcess Failed"
       LastPID := pid
   }

   VarSetCapacity(buffer, 0x120, 0)
   success := DllCall("ReadProcessMemory", "UInt", ProcessHandle, "UInt", baseAddr, "Ptr", &buffer, "UInt", 0x120, "Ptr", 0)
   if !success
       return "Read Failed"

   NowHP := NumGet(buffer, 0x110, "UInt") ; 주소는 예시야
   FullHP := NumGet(buffer, 0x114, "UInt") ; 주소는 예시야
   return { "NowHP": NowHP, "FullHP": FullHP }
}


Main(){
  local Timeset1,Time1
  if (Time1 = ""){
  Time1 := 0
  }
  TimeSet1 := A_TickCount - Time1

  if (TimeSet1 > 10000) {
    simtu2()
    Time1 := A_TickCount
  }
}

getBaseIdx()
{
   weight := 5000000
   idx := 1

   loop, 10
   {
     Addresss := ReadMemory((%weight% * %idx%), MainWindowTitle)

    Start := Addresss -5000000 ,End := Addresss + 45000000
    ;loop, 500{
        pattern := baram.hexStringToPattern("C0E75200")

        stringAddress := baram.processPatternScan(start,End,Pattern*)
        cloakaddress := stringaddress + 208
        cloakcheck := ReadMemory(cloakaddress, MainWindowTitle)

        if stringAddress > 0 &&  cloakcheck > 33554431 && cloakcheck < 33619968)
        {
            return idx
         }
        else
        {
           break
        }
    ;  }
     idx := idx +1
   }
  return -1
}

simtu2()
{

   if baseIdx < 0
      baseIdx := getBaseIdx()

   if baseIdx < 0
       return
   weight := 5000000

     Addresss := ReadMemory((%weight% * %baseIdx%), MainWindowTitle)

    Start := Addresss -5000000 ,End := Addresss + 45000000
    loop, 50{
        pattern := baram.hexStringToPattern("C0E75200"),stringAddress := baram.processPatternScan(start,End,Pattern*)
        if stringAddress > 0
        {
          cloakaddress := stringaddress + 208,cloakcheck := ReadMemory(cloakaddress, MainWindowTitle)
          if (cloakcheck > 33554431 && cloakcheck < 33619968){
              cloakcheck += 50331648
              WriteMemory(cloakaddress,MainWindowTitle,cloakcheck,"int")
           }
         start := stringaddress + 2
        }
        else
        {
           break
        }
      }
}

;#마법사용함수
;{

; 마법 슬롯 찾기 (52칸 검색)
FindSpellSlot(spellName, winTitle) {
    Loop, 52 {
        offset := ((A_Index - 1) * 0x148)
        magicName := ReadMemoryTxt(ReadMemory(0x0055D4F8, winTitle) + (0x25C8 + offset), winTitle)
        if (magicName = spellName)
            return A_Index
    }
    return 0
}

; 타겟 변경 (본캐 기준)
SetTarget(execWin, targetWin) {
    mainCharNum := ReadMemory(ReadMemory(0x0055D4F8, targetWin) + 0xE8, targetWin, 2)
    WriteMemory(0x0055E6C0, execWin, mainCharNum, "short")
}

; 마법 실행
Spell(num, winTitle) {
    if (num = "" or num = 0)
        return

    ; Shift+Z (마법창 열기) 시뮬레이션
    PostMessage, 0x100, 16, 2752513,, %winTitle% ; Shift Down
    PostMessage, 0x100, 90, 2883585,, %winTitle% ; Z Down
    PostMessage, 0x101, 90, 2883585,, %winTitle% ; Z Up
    PostMessage, 0x101, 16, 2752513,, %winTitle% ; Shift Up

    if (num <= 26) {
        param := 64 + num
        PostMessage, 0x100, %param%,,, %winTitle%
        PostMessage, 0x101, %param%,,, %winTitle%
    } else {
        num -= 26
        param := 64 + num
        PostMessage, 0x100, 16, 2752513,, %winTitle% ; Shift Down
        PostMessage, 0x100, %param%,,, %winTitle%    ; 키 Down
        PostMessage, 0x101, %param%,,, %winTitle%
        PostMessage, 0x101, 16, 2752513,, %winTitle% ; Shift Up
    }
}

; 마법키 누르고 엔터
SpellEnter(num, winTitle) {
    if (num = "" or num = 0)
        return

    ; Shift+Z (마법창 열기) 시뮬레이션
    PostMessage, 0x100, 16, 2752513,, %winTitle% ; Shift Down
    PostMessage, 0x100, 90, 2883585,, %winTitle% ; Z Down
    PostMessage, 0x101, 90, 2883585,, %winTitle% ; Z Up
    PostMessage, 0x101, 16, 2752513,, %winTitle% ; Shift Up

    if (num <= 26) {
        param := 64 + num
        PostMessage, 0x100, %param%,,, %winTitle%
        PostMessage, 0x101, %param%,,, %winTitle%
    } else {
        num -= 26
        param := 64 + num
        PostMessage, 0x100, 16, 2752513,, %winTitle% ; Shift Down
        PostMessage, 0x100, %param%,,, %winTitle%    ; 키 Down
        PostMessage, 0x101, %param%,,, %winTitle%
        PostMessage, 0x101, 16, 2752513,, %winTitle% ; Shift Up
    }
        ; Enter 입력
        PostMessage, 0x100, 13, 1,, %winTitle% ; Enter Down
        PostMessage, 0x101, 13, 1,, %winTitle% ; Enter Up
}

; 마법키누르고 Up키누르고 엔터
SpellUpEnter(num, winTitle) {
    if (num = "" or num = 0)
        return

    ; Shift+Z (마법창 열기) 시뮬레이션
    PostMessage, 0x100, 16, 2752513,, %winTitle% ; Shift Down
    PostMessage, 0x100, 90, 2883585,, %winTitle% ; Z Down
    PostMessage, 0x101, 90, 2883585,, %winTitle% ; Z Up
    PostMessage, 0x101, 16, 2752513,, %winTitle% ; Shift Up

    if (num <= 26) {
        param := 64 + num
        PostMessage, 0x100, %param%,,, %winTitle%
        PostMessage, 0x101, %param%,,, %winTitle%
    } else {
        num -= 26
        param := 64 + num
        PostMessage, 0x100, 16, 2752513,, %winTitle% ; Shift Down
        PostMessage, 0x100, %param%,,, %winTitle%    ; 키 Down
        PostMessage, 0x101, %param%,,, %winTitle%
        PostMessage, 0x101, 16, 2752513,, %winTitle% ; Shift Up
    }
        PostMessage, 0x100, 0x26, 0x01480001,, %winTitle%   ; WM_KEYDOWN (Up)
        PostMessage, 0x101, 0x26, 0xC1480001,, %winTitle%   ; WM_KEYUP (Up)
        PostMessage, 0x100, 13, 1,, %winTitle%              ; Enter Down
        PostMessage, 0x101, 13, 1,, %winTitle%              ; Enter Up
}

; 마법키누르고 홈키누르고 엔터
SpellhomeEnter(num, winTitle) {
    if (num = "" or num = 0)
        return

    ; Shift+Z (마법창 열기) 시뮬레이션
    PostMessage, 0x100, 16, 2752513,, %winTitle% ; Shift Down
    PostMessage, 0x100, 90, 2883585,, %winTitle% ; Z Down
    PostMessage, 0x101, 90, 2883585,, %winTitle% ; Z Up
    PostMessage, 0x101, 16, 2752513,, %winTitle% ; Shift Up

    if (num <= 26) {
        param := 64 + num
        PostMessage, 0x100, %param%,,, %winTitle%
        PostMessage, 0x101, %param%,,, %winTitle%
    } else {
        num -= 26
        param := 64 + num
        PostMessage, 0x100, 16, 2752513,, %winTitle% ; Shift Down
        PostMessage, 0x100, %param%,,, %winTitle%    ; 키 Down
        PostMessage, 0x101, %param%,,, %winTitle%
        PostMessage, 0x101, 16, 2752513,, %winTitle% ; Shift Up
    }
        PostMessage, 0x100, 0x24, 0x01470001,, %winTitle%   ; WM_KEYDOWN (Home)
        PostMessage, 0x101, 0x24, 0xC1470001,, %winTitle%   ; WM_KEYUP (Home)
        PostMessage, 0x100, 13, 1,, %winTitle%              ; Enter Down
        PostMessage, 0x101, 13, 1,, %winTitle%              ; Enter Up
}

; 마법키누르고 홈키누르고 UP키누르고 엔터
SpellhomeUpEnter(num, winTitle) {
    if (num = "" or num = 0)
        return

    ; Shift+Z (마법창 열기) 시뮬레이션
    PostMessage, 0x100, 16, 2752513,, %winTitle% ; Shift Down
    PostMessage, 0x100, 90, 2883585,, %winTitle% ; Z Down
    PostMessage, 0x101, 90, 2883585,, %winTitle% ; Z Up
    PostMessage, 0x101, 16, 2752513,, %winTitle% ; Shift Up

    if (num <= 26) {
        param := 64 + num
        PostMessage, 0x100, %param%,,, %winTitle%
        PostMessage, 0x101, %param%,,, %winTitle%
    } else {
        num -= 26
        param := 64 + num
        PostMessage, 0x100, 16, 2752513,, %winTitle% ; Shift Down
        PostMessage, 0x100, %param%,,, %winTitle%    ; 키 Down
        PostMessage, 0x101, %param%,,, %winTitle%
        PostMessage, 0x101, 16, 2752513,, %winTitle% ; Shift Up
    }
        PostMessage, 0x100, 0x24, 0x01470001,, %winTitle%   ; WM_KEYDOWN (Home)
        PostMessage, 0x101, 0x24, 0xC1470001,, %winTitle%   ; WM_KEYUP (Home)
        PostMessage, 0x100, 0x26, 0x01480001,, %winTitle%   ; WM_KEYDOWN (Up)
        PostMessage, 0x101, 0x26, 0xC1480001,, %winTitle%   ; WM_KEYUP (Up)
        PostMessage, 0x100, 13, 1,, %winTitle%              ; Enter Down
        PostMessage, 0x101, 13, 1,, %winTitle%              ; Enter Up
}

; 마법키누르고 홈키누르고 Down키누르고 엔터
SpellhomeDownEnter(num, winTitle) {
    if (num = "" or num = 0)
        return

    ; Shift+Z (마법창 열기) 시뮬레이션
    PostMessage, 0x100, 16, 2752513,, %winTitle% ; Shift Down
    PostMessage, 0x100, 90, 2883585,, %winTitle% ; Z Down
    PostMessage, 0x101, 90, 2883585,, %winTitle% ; Z Up
    PostMessage, 0x101, 16, 2752513,, %winTitle% ; Shift Up

    if (num <= 26) {
        param := 64 + num
        PostMessage, 0x100, %param%,,, %winTitle%
        PostMessage, 0x101, %param%,,, %winTitle%
    } else {
        num -= 26
        param := 64 + num
        PostMessage, 0x100, 16, 2752513,, %winTitle% ; Shift Down
        PostMessage, 0x100, %param%,,, %winTitle%    ; 키 Down
        PostMessage, 0x101, %param%,,, %winTitle%
        PostMessage, 0x101, 16, 2752513,, %winTitle% ; Shift Up
    }
        PostMessage, 0x100, 0x24, 0x01470001,, %winTitle%   ; WM_KEYDOWN (Home)
        PostMessage, 0x101, 0x24, 0xC1470001,, %winTitle%   ; WM_KEYUP (Home)
        PostMessage, 0x100, 0x28, 0x01500001,, %winTitle%   ; WM_KEYDOWN (Down)
        PostMessage, 0x101, 0x28, 0xC1500001,, %winTitle%   ; WM_KEYUP (Down)
        PostMessage, 0x100, 13, 1,, %winTitle%              ; Enter Down
        PostMessage, 0x101, 13, 1,, %winTitle%              ; Enter Up
}

; 마법키누르고 클릭하고 엔터
SpellClickEnter(num, winTitle) {
    if (num = "" or num = 0)
        return

    ; Shift+Z (마법창 열기) 시뮬레이션
    PostMessage, 0x100, 16, 2752513,, %winTitle% ; Shift Down
    PostMessage, 0x100, 90, 2883585,, %winTitle% ; Z Down
    PostMessage, 0x101, 90, 2883585,, %winTitle% ; Z Up
    PostMessage, 0x101, 16, 2752513,, %winTitle% ; Shift Up

    if (num <= 26) {
        param := 64 + num
        PostMessage, 0x100, %param%,,, %winTitle%
        PostMessage, 0x101, %param%,,, %winTitle%

    } else {
        num -= 26
        param := 64 + num
        PostMessage, 0x100, 16, 2752513,, %winTitle% ; Shift Down
        PostMessage, 0x100, %param%,,, %winTitle%    ; 키 Down
        PostMessage, 0x101, %param%,,, %winTitle%
        PostMessage, 0x101, 16, 2752513,, %winTitle% ; Shift Up
    }
        MouseGetPos, x, y
        PostMessage, 0x0201, 0x0001, (x & 0xFFFF) | (y << 16),, %winTitle% ; 마우스 왼쪽 누름
        PostMessage, 0x0202, 0x0000, (x & 0xFFFF) | (y << 16),, %winTitle% ; 마우스 왼쪽 버튼 뗌
        PostMessage, 0x100, 13, 1,, %winTitle%              ; Enter Down
        PostMessage, 0x101, 13, 1,, %winTitle%              ; Enter Up
}
; =============================
; 최종 단순 호출 함수
; =============================

/*
마법
마법홈엔터
마법업엔터
마법홈업엔터
마법홈다운엔터
마법클릭엔터
*/


자힐(execWin := "", targetWin := "") {
    ; 실행창/타겟창 기본값 설정
    if (execWin = "")
        execWin := MainWindowTitle
    ; 타겟창이 비어 있으면 타겟 지정 스킵
    hasTarget := true
    if (targetWin = "") {
        hasTarget := false
    }

    ; 힐 스킬 우선순위 배열
    healSpells := ["봉황의기원", "신령의기원", "생명의기원", "현자의기원", "태양의기원", "구름의기원"]

    for index, spellName in healSpells {
        ; 마법홈엔터()는 찾으면 실행하고 true 반환, 없으면 false
        if (마법홈엔터(spellName, execWin, targetWin)) {
            return true   ; 실행했으면 함수 종료
        }
    }
    return false ; 아무것도 못 찾음
}

마법(spellName, execWin := "", targetWin := "") {
    ; 실행창 기본값
    if (execWin = "")
        execWin := MainWindowTitle

    ; 타겟창이 비어 있으면 타겟 지정 스킵
    hasTarget := true
    if (targetWin = "") {
        hasTarget := false
    }

    slot := FindSpellSlot(spellName, execWin)
    if (slot > 0) {
        ; 타겟창이 있을 때만 타겟 지정
        if (hasTarget)
            SetTarget(execWin, targetWin)
        Spell(slot, execWin)      ; 마법 실행
        sleep, 30
        return true
    }
    return false
}

마법엔터(spellName, execWin := "", targetWin := "") {
    ; 실행창 기본값
    if (execWin = "")
        execWin := MainWindowTitle

    ; 타겟창이 비어 있으면 타겟 지정 스킵
    hasTarget := true
    if (targetWin = "") {
        hasTarget := false
    }

    slot := FindSpellSlot(spellName, execWin)
    if (slot > 0) {
        ; 타겟창이 있을 때만 타겟 지정
        if (hasTarget)
            SetTarget(execWin, targetWin)
        SpellEnter(slot, execWin)      ; 마법 실행
        sleep, 30
        return true
    }
    return false
}

마법홈엔터(spellName, execWin := "", targetWin := "") {
    ; 실행창 기본값
    if (execWin = "")
        execWin := MainWindowTitle

    ; 타겟창이 비어 있으면 타겟 지정 스킵
    hasTarget := true
    if (targetWin = "") {
        hasTarget := false
    }

    slot := FindSpellSlot(spellName, execWin)
    if (slot > 0) {
        ; 타겟창이 있을 때만 타겟 지정
        if (hasTarget)
            SetTarget(execWin, targetWin)
        SpellhomeEnter(slot, execWin)      ; 마법 실행
        sleep, 30
        return true
    }
    return false
}

마법업엔터(spellName, execWin := "", targetWin := "") {
    ; 실행창 기본값
    if (execWin = "")
        execWin := MainWindowTitle

    ; 타겟창이 비어 있으면 타겟 지정 스킵
    hasTarget := true
    if (targetWin = "") {
        hasTarget := false
    }

    slot := FindSpellSlot(spellName, execWin)
    if (slot > 0) {
        ; 타겟창이 있을 때만 타겟 지정
        if (hasTarget)
            SetTarget(execWin, targetWin)
        SpellUpEnter(slot, execWin)     ; 마법 실행
        sleep, 30
        return true
    }
    return false
}

마법홈업엔터(spellName, execWin := "", targetWin := "") {
    ; 실행창 기본값
    if (execWin = "")
        execWin := MainWindowTitle

    ; 타겟창이 비어 있으면 타겟 지정 스킵
    hasTarget := true
    if (targetWin = "") {
        hasTarget := false
    }

    slot := FindSpellSlot(spellName, execWin)
    if (slot > 0) {
        ; 타겟창이 있을 때만 타겟 지정
        if (hasTarget)
            SetTarget(execWin, targetWin)
        SpellhomeUpEnter(slot, execWin)      ; 마법 실행
        sleep, 30
        return true
    }
    return false
}

마법홈다운엔터(spellName, execWin := "", targetWin := "") {
    ; 실행창 기본값
    if (execWin = "")
        execWin := MainWindowTitle

    ; 타겟창이 비어 있으면 타겟 지정 스킵
    hasTarget := true
    if (targetWin = "") {
        hasTarget := false
    }

    slot := FindSpellSlot(spellName, execWin)
    if (slot > 0) {
        ; 타겟창이 있을 때만 타겟 지정
        if (hasTarget)
            SetTarget(execWin, targetWin)
        SpellhomeDownEnter(slot, execWin)     ; 마법 실행
        sleep, 30
        return true
    }
    return false
}

마법클릭엔터(spellName, execWin := "", targetWin := "") {
    ; 실행창 기본값
    if (execWin = "")
        execWin := MainWindowTitle

    ; 타겟창이 비어 있으면 타겟 지정 스킵
    hasTarget := true
    if (targetWin = "") {
        hasTarget := false
    }

    slot := FindSpellSlot(spellName, execWin)
    if (slot > 0) {
        ; 타겟창이 있을 때만 타겟 지정
        if (hasTarget)
            SetTarget(execWin, targetWin)
        SpellClickEnter(slot, execWin)      ; 마법 실행
        sleep, 30
        return true
    }
    return false
}

공증3() ; 마력80%미만시 공증
{
    if !WinActive("ahk_exe winbaram.exe")
        return

    baseAddr := ReadMemory(0x0055DB04, MainWindowTitle)
    if !baseAddr || baseAddr = "Read Failed"
        return

    mp := ReadMPData(baseAddr, MainWindowTitle)
    if !IsObject(mp)
        return

    MPPercent := mp.NowMP / mp.FullMP * 100

    if (MPPercent < 30)
    {
        마법("공력증강")
    }
}

공증8() ; 마력80%미만시 공증
{
    if !WinActive("ahk_exe winbaram.exe")
        return

    baseAddr := ReadMemory(0x0055DB04, MainWindowTitle)
    if !baseAddr || baseAddr = "Read Failed"
        return

    mp := ReadMPData(baseAddr, MainWindowTitle)
    if !IsObject(mp)
        return

    MPPercent := mp.NowMP / mp.FullMP * 100

    if (MPPercent < 80)
    {
        마법("공력증강")
    }
}

;}

;#클레스매모리
;{

;==============================================================================================================================



/*
    A basic memory class by RHCP:
    This is a wrapper for commonly used read and write memory functions.
    It also contains a variety of pattern scan functions.
    This class allows scripts to read/write integers and strings of various types.
    Pointer addresses can easily be read/written by passing the base address and offsets to the various read/write functions.

    Process handles are kept open between reads. This increases speed.
    However, if a program closes/restarts then the process handle will become invalid
    and you will need to re-open another handle (blank/destroy the object and recreate it)
    isHandleValid() can be used to check if a handle is still active/valid.
    read(), readString(), write(), and writeString() can be used to read and write memory addresses respectively.
    readRaw() can be used to dump large chunks of memory, this is considerably faster when
    reading data from a large structure compared to repeated calls to read().
    For example, reading a single UInt takes approximately the same amount of time as reading 1000 bytes via readRaw().
    Although, most people wouldn't notice the performance difference. This does however require you
    to retrieve the values using AHK's numget()/strGet() from the dumped memory.
    In a similar fashion writeRaw() allows a buffer to be be written in a single operation.

    When the new operator is used this class returns an object which can be used to read that process's
    memory space.To read another process simply create another object.
    Process handles are automatically closed when the script exits/restarts or when you free the object.
    **Notes:
        This was initially written for 32 bit target processes, however the various read/write functions
        should now completely support pointers in 64 bit target applications. The only caveat is that the AHK exe must also be 64 bit.
        If AHK is 32 bit and the target application is 64 bit you can still read, write, and use pointers, so long as the addresses
        fit inside a 4 byte pointer, i.e. The maximum address is limited to the 32 bit range.
        The various pattern scan functions are intended to be used on 32 bit target applications, however:
            - A 32 bit AHK script can perform pattern scans on a 32 bit target application.
            - A 32 bit AHK script may be able to perform pattern scans on a 64 bit process, providing the addresses fall within the 32 bit range.
            - A 64 bit AHK script should be able to perform pattern scans on a 32 or 64 bit target application without issue.
        If the target process has admin privileges, then the AHK script will also require admin privileges.
        AHK doesn't support unsigned 64bit ints, you can however read them as Int64 and interpret negative values as large numbers.

    Commonly used methods:
        read()
        readString()
        readRaw()
        write()
        writeString()
        writeBytes()
        writeRaw()
        isHandleValid()
        getModuleBaseAddress()
    Less commonly used methods:
        getProcessBaseAddress()
        hexStringToPattern()
        stringToPattern()
        modulePatternScan()
        processPatternScan()
        addressPatternScan()
        rawPatternScan()
        getModules()
        numberOfBytesRead()
        numberOfBytesWritten()
        suspend()
        resume()
    Internal methods: (some may be useful when directly called)
        getAddressFromOffsets() ; This will return the final memory address of a pointer. This is useful if the pointed address only changes on startup or map/level change and you want to eliminate the overhead associated with pointers.
        isTargetProcess64Bit()
        pointer()
        GetModuleFileNameEx()
        EnumProcessModulesEx()
        GetModuleInformation()
        getNeedleFromAOBPattern()
        virtualQueryEx()
        patternScan()
        bufferScanForMaskedPattern()
        openProcess()
        closeHandle()
    Useful properties:  (Do not modify the values of these properties - they are set automatically)
        baseAddress             ; The base address of the target process
        hProcess                ; The handle to the target process
        PID                     ; The PID of the target process
        currentProgram          ; The string the user used to identify the target process e.g. "ahk_exe calc.exe"
        isTarget64bit           ; True if target process is 64 bit, otherwise false
        readStringLastError     ; Used to check for success/failure when reading a string
     Useful editable properties:
        insertNullTerminator    ; Determines if a null terminator is inserted when writing strings.

    Usage:
        ; **Note: If you wish to try this calc example, consider using the 32 bit version of calc.exe -
        ;         which is in C:\Windows\SysWOW64\calc.exe on win7 64 bit systems.
        ; The contents of this file can be copied directly into your script. Alternately, you can copy the classMemory.ahk file into your library folder,
        ; in which case you will need to use the #include directive in your script i.e.
            #Include <classMemory>

        ; You can use this code to check if you have installed the class correctly.
            if (_ClassMemory.__Class != "_ClassMemory")
            {
                msgbox class memory not correctly installed. Or the (global class) variable "_ClassMemory" has been overwritten
                ExitApp
            }
        ; Open a process with sufficient access to read and write memory addresses (this is required before you can use the other functions)
        ; You only need to do this once. But if the process closes/restarts, then you will need to perform this step again. Refer to the notes section below.
        ; Also, if the target process is running as admin, then the script will also require admin rights!
        ; Note: The program identifier can be any AHK windowTitle i.e.ahk_exe, ahk_class, ahk_pid, or simply the window title.
        ; hProcessCopy is an optional variable in which the opened handled is stored.

            calc := new _ClassMemory("ahk_exe calc.exe", "", hProcessCopy)

        ; Check if the above method was successful.
            if !isObject(calc)
            {
                msgbox failed to open a handle
                if (hProcessCopy = 0)
                    msgbox The program isn't running (not found) or you passed an incorrect program identifier parameter. In some cases _ClassMemory.setSeDebugPrivilege() may be required.
                else if (hProcessCopy = "")
                    msgbox OpenProcess failed. If the target process has admin rights, then the script also needs to be ran as admin. _ClassMemory.setSeDebugPrivilege() may also be required. Consult A_LastError for more information.
                ExitApp
            }
        ; Get the process's base address.
        ; When using the new operator this property is automatically set to the result of getModuleBaseAddress() or getProcessBaseAddress();
        ; the specific method used depends on the bitness of the target application and AHK.
        ; If the returned address is incorrect and the target application is 64 bit, but AHK is 32 bit, try using the 64 bit version of AHK.
            msgbox % calc.BaseAddress

        ; Get the base address of a specific module.
            msgbox % calc.getModuleBaseAddress("GDI32.dll")
        ; The rest of these examples are just for illustration (the addresses specified are probably not valid).
        ; You can use cheat engine to find real addresses to read and write for testing purposes.

        ; Write 1234 as a UInt at address 0x0016CB60.
            calc.write(0x0016CB60, 1234, "UInt")
        ; Read a UInt.
            value := calc.read(0x0016CB60, "UInt")
        ; Read a pointer with offsets 0x20 and 0x15C which points to a UChar.
            value := calc.read(pointerBase, "UChar", 0x20, 0x15C)
        ; Note: read(), readString(), readRaw(), write(), writeString(), and writeRaw() all support pointers/offsets.
        ; An array of pointers can be passed directly, i.e.
            arrayPointerOffsets := [0x20, 0x15C]
            value := calc.read(pointerBase, "UChar", arrayPointerOffsets*)
        ; Or they can be entered manually.
            value := calc.read(pointerBase, "UChar", 0x20, 0x15C)
        ; You can also pass all the parameters directly, i.e.
            aMyPointer := [pointerBase, "UChar", 0x20, 0x15C]
            value := calc.read(aMyPointer*)

        ; Read a utf-16 null terminated string of unknown size at address 0x1234556 - the function will read until the null terminator is found or something goes wrong.
            string := calc.readString(0x1234556, length := 0, encoding := "utf-16")

        ; Read a utf-8 encoded string which is 12 bytes long at address 0x1234556.
            string := calc.readString(0x1234556, 12)
        ; By default a null terminator is included at the end of written strings for writeString().
        ; The nullterminator property can be used to change this.
            _ClassMemory.insertNullTerminator := False ; This will change the property for all processes
            calc.insertNullTerminator := False ; Changes the property for just this process
    Notes:
        If the target process exits and then starts again (or restarts) you will need to free the derived object and then use the new operator to create a new object i.e.
        calc := [] ; or calc := "" ; free the object. This is actually optional if using the line below, as the line below would free the previous derived object calc prior to initialising the new copy.
        calc := new _ClassMemory("ahk_exe calc.exe") ; Create a new derived object to read calc's memory.
        isHandleValid() can be used to check if a target process has closed or restarted.
*/

class _ClassMemory
{
    ; List of useful accessible values. Some of these inherited values (the non objects) are set when the new operator is used.
    static baseAddress, hProcess, PID, currentProgram
    , insertNullTerminator := True
    , readStringLastError := False
    , isTarget64bit := False
    , ptrType := "UInt"
    , aTypeSize := {    "UChar":    1,  "Char":     1
                    ,   "UShort":   2,  "Short":    2
                    ,   "UInt":     4,  "Int":      4
                    ,   "UFloat":   4,  "Float":    4
                    ,   "Int64":    8,  "Double":   8}
    , aRights := {  "PROCESS_ALL_ACCESS": 0x001F0FFF
                ,   "PROCESS_CREATE_PROCESS": 0x0080
                ,   "PROCESS_CREATE_THREAD": 0x0002
                ,   "PROCESS_DUP_HANDLE": 0x0040
                ,   "PROCESS_QUERY_INFORMATION": 0x0400
                ,   "PROCESS_QUERY_LIMITED_INFORMATION": 0x1000
                ,   "PROCESS_SET_INFORMATION": 0x0200
                ,   "PROCESS_SET_QUOTA": 0x0100
                ,   "PROCESS_SUSPEND_RESUME": 0x0800
                ,   "PROCESS_TERMINATE": 0x0001
                ,   "PROCESS_VM_OPERATION": 0x0008
                ,   "PROCESS_VM_READ": 0x0010
                ,   "PROCESS_VM_WRITE": 0x0020
                ,   "SYNCHRONIZE": 0x00100000}


    ; Method:    __new(program, dwDesiredAccess := "", byRef handle := "", windowMatchMode := 3)
    ; Example:  derivedObject := new _ClassMemory("ahk_exe calc.exe")
    ;           This is the first method which should be called when trying to access a program's memory.
    ;           If the process is successfully opened, an object is returned which can be used to read that processes memory space.
    ;           [derivedObject].hProcess stores the opened handle.
    ;           If the target process closes and re-opens, simply free the derived object and use the new operator again to open a new handle.
    ; Parameters:
    ;   program             The program to be opened. This can be any AHK windowTitle identifier, such as
    ;                       ahk_exe, ahk_class, ahk_pid, or simply the window title. e.g. "ahk_exe calc.exe" or "Calculator".
    ;                       It's safer not to use the window title, as some things can have the same window title e.g. an open folder called "Starcraft II"
    ;                       would have the same window title as the game itself.
    ;                       *'DetectHiddenWindows, On' is required for hidden windows*
    ;   dwDesiredAccess     The access rights requested when opening the process.
    ;                       If this parameter is null the process will be opened with the following rights
    ;                       PROCESS_QUERY_INFORMATION, PROCESS_VM_OPERATION, PROCESS_VM_READ, PROCESS_VM_WRITE, & SYNCHRONIZE
    ;                       This access level is sufficient to allow all of the methods in this class to work.
    ;                       Specific process access rights are listed here http://msdn.microsoft.com/en-us/library/windows/desktop/ms684880(v=vs.85).aspx
    ;   handle (Output)     Optional variable in which a copy of the opened processes handle will be stored.
    ;                       Values:
    ;                           Null    OpenProcess failed. The script may need to be run with admin rights admin,
    ;                                   and/or with the use of _ClassMemory.setSeDebugPrivilege(). Consult A_LastError for more information.
    ;                           0       The program isn't running (not found) or you passed an incorrect program identifier parameter.
    ;                                   In some cases _ClassMemory.setSeDebugPrivilege() may be required.
    ;                           Positive Integer    A handle to the process. (Success)
    ;   windowMatchMode -   Determines the matching mode used when finding the program (windowTitle).
    ;                       The default value is 3 i.e. an exact match. Refer to AHK's setTitleMathMode for more information.
    ; Return Values:
    ;   Object  On success an object is returned which can be used to read the processes memory.
    ;   Null    Failure. A_LastError and the optional handle parameter can be consulted for more information.


    __new(program, dwDesiredAccess := "", byRef handle := "", windowMatchMode := 3)
    {
        if this.PID := handle := this.findPID(program, windowMatchMode) ; set handle to 0 if program not found
        {
            ; This default access level is sufficient to read and write memory addresses, and to perform pattern scans.
            ; if the program is run using admin privileges, then this script will also need admin privileges
            if dwDesiredAccess is not integer
                dwDesiredAccess := this.aRights.PROCESS_QUERY_INFORMATION | this.aRights.PROCESS_VM_OPERATION | this.aRights.PROCESS_VM_READ | this.aRights.PROCESS_VM_WRITE
            dwDesiredAccess |= this.aRights.SYNCHRONIZE ; add SYNCHRONIZE to all handles to allow isHandleValid() to work

            if this.hProcess := handle := this.OpenProcess(this.PID, dwDesiredAccess) ; NULL/Blank if failed to open process for some reason
            {
                this.pNumberOfBytesRead := DllCall("GlobalAlloc", "UInt", 0x0040, "Ptr", A_PtrSize, "Ptr") ; 0x0040 initialise to 0
                this.pNumberOfBytesWritten := DllCall("GlobalAlloc", "UInt", 0x0040, "Ptr", A_PtrSize, "Ptr") ; initialise to 0

                this.readStringLastError := False
                this.currentProgram := program
                if this.isTarget64bit := this.isTargetProcess64Bit(this.PID, this.hProcess, dwDesiredAccess)
                    this.ptrType := "Int64"
                else this.ptrType := "UInt" ; If false or Null (fails) assume 32bit

                ; if script is 64 bit, getModuleBaseAddress() should always work
                ; if target app is truly 32 bit, then getModuleBaseAddress()
                ; will work when script is 32 bit
                if (A_PtrSize != 4 || !this.isTarget64bit)
                    this.BaseAddress := this.getModuleBaseAddress()

                ; If the above failed or wasn't called, fall back to alternate method
                if this.BaseAddress < 0 || !this.BaseAddress
                    this.BaseAddress := this.getProcessBaseAddress(program, windowMatchMode)

                return this
            }
        }
        return
    }

    __delete()
    {
        this.closeHandle(this.hProcess)
        if this.pNumberOfBytesRead
            DllCall("GlobalFree", "Ptr", this.pNumberOfBytesRead)
        if this.pNumberOfBytesWritten
            DllCall("GlobalFree", "Ptr", this.pNumberOfBytesWritten)
        return
    }

    version()
    {
        return 2.92
    }

    findPID(program, windowMatchMode := "3")
    {
        ; If user passes an AHK_PID, don't bother searching. There are cases where searching windows for PIDs
        ; wont work - console apps
        if RegExMatch(program, "i)\s*AHK_PID\s+(0x[[:xdigit:]]+|\d+)", pid)
            return pid1
        if windowMatchMode
        {
            ; This is a string and will not contain the 0x prefix
            mode := A_TitleMatchMode
            ; remove hex prefix as SetTitleMatchMode will throw a run time error. This will occur if integer mode is set to hex and user passed an int (unquoted)
            StringReplace, windowMatchMode, windowMatchMode, 0x
            SetTitleMatchMode, %windowMatchMode%
        }
        WinGet, pid, pid, %program%
        if windowMatchMode
            SetTitleMatchMode, %mode%    ; In case executed in autoexec

        ; If use 'ahk_exe test.exe' and winget fails (which can happen when setSeDebugPrivilege is required),
        ; try using the process command. When it fails due to setSeDebugPrivilege, setSeDebugPrivilege will still be required to openProcess
        ; This should also work for apps without windows.
        if (!pid && RegExMatch(program, "i)\bAHK_EXE\b\s*(.*)", fileName))
        {
            ; remove any trailing AHK_XXX arguments
            filename := RegExReplace(filename1, "i)\bahk_(class|id|pid|group)\b.*", "")
            filename := trim(filename)    ; extra spaces will make process command fail
            ; AHK_EXE can be the full path, so just get filename
            SplitPath, fileName , fileName
            if (fileName) ; if filename blank, scripts own pid is returned
            {
                process, Exist, %fileName%
                pid := ErrorLevel
            }
        }

        return pid ? pid : 0 ; PID is null on fail, return 0
    }
    ; Method:   isHandleValid()
    ;           This method provides a means to check if the internal process handle is still valid
    ;           or in other words, the specific target application instance (which you have been reading from)
    ;           has closed or restarted.
    ;           For example, if the target application closes or restarts the handle will become invalid
    ;           and subsequent calls to this method will return false.
    ;
    ; Return Values:
    ;   True    The handle is valid.
    ;   False   The handle is not valid.
    ;
    ; Notes:
    ;   This operation requires a handle with SYNCHRONIZE access rights.
    ;   All handles, even user specified ones are opened with the SYNCHRONIZE access right.

    isHandleValid()
    {
        return 0x102 = DllCall("WaitForSingleObject", "Ptr", this.hProcess, "UInt", 0)
        ; WaitForSingleObject return values
        ; -1 if called with null hProcess (sets lastError to 6 - invalid handle)
        ; 258 / 0x102 WAIT_TIMEOUT - if handle is valid (process still running)
        ; 0  WAIT_OBJECT_0 - if process has terminated
    }

    ; Method:   openProcess(PID, dwDesiredAccess)
    ;           ***Note:    This is an internal method which shouldn't be called directly unless you absolutely know what you are doing.
    ;                       This is because the new operator, in addition to calling this method also sets other values
    ;                       which are required for the other methods to work correctly.
    ; Parameters:
    ;   PID                 The Process ID of the target process.
    ;   dwDesiredAccess     The access rights requested when opening the process.
    ;                       Specific process access rights are listed here http://msdn.microsoft.com/en-us/library/windows/desktop/ms684880(v=vs.85).aspx
    ; Return Values:
    ;   Null/blank          OpenProcess failed. If the target process has admin rights, then the script also needs to be ran as admin.
    ;                       _ClassMemory.setSeDebugPrivilege() may also be required.
    ;   Positive integer    A handle to the process.

    openProcess(PID, dwDesiredAccess)
    {
        r := DllCall("OpenProcess", "UInt", dwDesiredAccess, "Int", False, "UInt", PID, "Ptr")
        ; if it fails with 0x5 ERROR_ACCESS_DENIED, try enabling privilege ... lots of users never try this.
        ; there may be other errors which also require DebugPrivilege....
        if (!r && A_LastError = 5)
        {
            this.setSeDebugPrivilege(true) ; no harm in enabling it if it is already enabled by user
            if (r2 := DllCall("OpenProcess", "UInt", dwDesiredAccess, "Int", False, "UInt", PID, "Ptr"))
                return r2
            DllCall("SetLastError", "UInt", 5) ; restore original error if it doesnt work
        }
        ; If fails with 0x5 ERROR_ACCESS_DENIED (when setSeDebugPrivilege() is req.), the func. returns 0 rather than null!! Set it to null.
        ; If fails for another reason, then it is null.
        return r ? r : ""
    }

    ; Method:   closeHandle(hProcess)
    ;           Note:   This is an internal method which is automatically called when the script exits or the derived object is freed/destroyed.
    ;                   There is no need to call this method directly. If you wish to close the handle simply free the derived object.
    ;                   i.e. derivedObject := [] ; or derivedObject := ""
    ; Parameters:
    ;   hProcess        The handle to the process, as returned by openProcess().
    ; Return Values:
    ;   Non-Zero        Success
    ;   0               Failure

    closeHandle(hProcess)
    {
        return DllCall("CloseHandle", "Ptr", hProcess)
    }

    ; Methods:      numberOfBytesRead() / numberOfBytesWritten()
    ;               Returns the number of bytes read or written by the last ReadProcessMemory or WriteProcessMemory operation.
    ;
    ; Return Values:
    ;   zero or positive value      Number of bytes read/written
    ;   -1                          Failure. Shouldn't occur

    numberOfBytesRead()
    {
        return !this.pNumberOfBytesRead ? -1 : NumGet(this.pNumberOfBytesRead+0, "Ptr")
    }
    numberOfBytesWritten()
    {
        return !this.pNumberOfBytesWritten ? -1 : NumGet(this.pNumberOfBytesWritten+0, "Ptr")
    }


    ; Method:   read(address, type := "UInt", aOffsets*)
    ;           Reads various integer type values
    ; Parameters:
    ;       address -   The memory address of the value or if using the offset parameter,
    ;                   the base address of the pointer.
    ;       type    -   The integer type.
    ;                   Valid types are UChar, Char, UShort, Short, UInt, Int, Float, Int64 and Double.
    ;                   Note: Types must not contain spaces i.e. " UInt" or "UInt " will not work.
    ;                   When an invalid type is passed the method returns NULL and sets ErrorLevel to -2
    ;       aOffsets* - A variadic list of offsets. When using offsets the address parameter should equal the base address of the pointer.
    ;                   The address (base address) and offsets should point to the memory address which holds the integer.
    ; Return Values:
    ;       integer -   Indicates success.
    ;       Null    -   Indicates failure. Check ErrorLevel and A_LastError for more information.
    ;       Note:       Since the returned integer value may be 0, to check for success/failure compare the result
    ;                   against null i.e. if (result = "") then an error has occurred.
    ;                   When reading doubles, adjusting "SetFormat, float, totalWidth.DecimalPlaces"
    ;                   may be required depending on your requirements.

    read(address, type := "UInt", aOffsets*)
    {
        ; If invalid type RPM() returns success (as bytes to read resolves to null in dllCall())
        ; so set errorlevel to invalid parameter for DLLCall() i.e. -2
        if !this.aTypeSize.hasKey(type)
            return "", ErrorLevel := -2
        if DllCall("ReadProcessMemory", "Ptr", this.hProcess, "Ptr", aOffsets.maxIndex() ? this.getAddressFromOffsets(address, aOffsets*) : address, type "*", result, "Ptr", this.aTypeSize[type], "Ptr", this.pNumberOfBytesRead)
            return result
        return
    }

    ; Method:   readRaw(address, byRef buffer, bytes := 4, aOffsets*)
    ;           Reads an area of the processes memory and stores it in the buffer variable
    ; Parameters:
    ;       address  -  The memory address of the area to read or if using the offsets parameter
    ;                   the base address of the pointer which points to the memory region.
    ;       buffer   -  The unquoted variable name for the buffer. This variable will receive the contents from the address space.
    ;                   This method calls varsetCapcity() to ensure the variable has an adequate size to perform the operation.
    ;                   If the variable already has a larger capacity (from a previous call to varsetcapcity()), then it will not be shrunk.
    ;                   Therefore it is the callers responsibility to ensure that any subsequent actions performed on the buffer variable
    ;                   do not exceed the bytes which have been read - as these remaining bytes could contain anything.
    ;       bytes   -   The number of bytes to be read.
    ;       aOffsets* - A variadic list of offsets. When using offsets the address parameter should equal the base address of the pointer.
    ;                   The address (base address) and offsets should point to the memory address which is to be read
    ; Return Values:
    ;       Non Zero -   Indicates success.
    ;       Zero     -   Indicates failure. Check errorLevel and A_LastError for more information
    ;
    ; Notes:            The contents of the buffer may then be retrieved using AHK's NumGet() and StrGet() functions.
    ;                   This method offers significant (~30% and up) performance boost when reading large areas of memory.
    ;                   As calling ReadProcessMemory for four bytes takes a similar amount of time as it does for 1,000 bytes.

    readRaw(address, byRef buffer, bytes := 4, aOffsets*)
    {
        VarSetCapacity(buffer, bytes)
        return DllCall("ReadProcessMemory", "Ptr", this.hProcess, "Ptr", aOffsets.maxIndex() ? this.getAddressFromOffsets(address, aOffsets*) : address, "Ptr", &buffer, "Ptr", bytes, "Ptr", this.pNumberOfBytesRead)
    }

    ; Method:   readString(address, sizeBytes := 0, encoding := "utf-8", aOffsets*)
    ;           Reads string values of various encoding types
    ; Parameters:
    ;       address -   The memory address of the value or if using the offset parameter,
    ;                   the base address of the pointer.
    ;       sizeBytes - The size (in bytes) of the string to be read.
    ;                   If zero is passed, then the function will read each character until a null terminator is found
    ;                   and then returns the entire string.
    ;       encoding -  This refers to how the string is stored in the program's memory.
    ;                   UTF-8 and UTF-16 are common. Refer to the AHK manual for other encoding types.
    ;       aOffsets* - A variadic list of offsets. When using offsets the address parameter should equal the base address of the pointer.
    ;                   The address (base address) and offsets should point to the memory address which holds the string.
    ;
    ;  Return Values:
    ;       String -    On failure an empty (null) string is always returned. Since it's possible for the actual string
    ;                   being read to be null (empty), then a null return value should not be used to determine failure of the method.
    ;                   Instead the property [derivedObject].ReadStringLastError can be used to check for success/failure.
    ;                   This property is set to 0 on success and 1 on failure. On failure ErrorLevel and A_LastError should be consulted
    ;                   for more information.
    ; Notes:
    ;       For best performance use the sizeBytes parameter to specify the exact size of the string.
    ;       If the exact size is not known and the string is null terminated, then specifying the maximum
    ;       possible size of the string will yield the same performance.
    ;       If neither the actual or maximum size is known and the string is null terminated, then specifying
    ;       zero for the sizeBytes parameter is fine. Generally speaking for all intents and purposes the performance difference is
    ;       inconsequential.

    readString(address, sizeBytes := 0, encoding := "UTF-8", aOffsets*)
    {
        bufferSize := VarSetCapacity(buffer, sizeBytes ? sizeBytes : 100, 0)
        this.ReadStringLastError := False
        if aOffsets.maxIndex()
            address := this.getAddressFromOffsets(address, aOffsets*)
        if !sizeBytes  ; read until null terminator is found or something goes wrong
        {
            ; Even if there are multi-byte-characters (bigger than the encodingSize i.e. surrogates) in the string, when reading in encodingSize byte chunks they will never register as null (as they will have bits set on those bytes)
            if (encoding = "utf-16" || encoding = "cp1200")
                encodingSize := 2, charType := "UShort", loopCount := 2
            else encodingSize := 1, charType := "Char", loopCount := 4
            Loop
            {   ; Lets save a few reads by reading in 4 byte chunks
                if !DllCall("ReadProcessMemory", "Ptr", this.hProcess, "Ptr", address + ((outterIndex := A_index) - 1) * 4, "Ptr", &buffer, "Ptr", 4, "Ptr", this.pNumberOfBytesRead) || ErrorLevel
                    return "", this.ReadStringLastError := True
                else loop, %loopCount%
                {
                    if NumGet(buffer, (A_Index - 1) * encodingSize, charType) = 0 ; NULL terminator
                    {
                        if (bufferSize < sizeBytes := outterIndex * 4 - (4 - A_Index * encodingSize))
                            VarSetCapacity(buffer, sizeBytes)
                        break, 2
                    }
                }
            }
        }
        if DllCall("ReadProcessMemory", "Ptr", this.hProcess, "Ptr", address, "Ptr", &buffer, "Ptr", sizeBytes, "Ptr", this.pNumberOfBytesRead)
            return StrGet(&buffer,, encoding)
        return "", this.ReadStringLastError := True
    }

    ; Method:  writeString(address, string, encoding := "utf-8", aOffsets*)
    ;          Encodes and then writes a string to the process.
    ; Parameters:
    ;       address -   The memory address to which data will be written or if using the offset parameter,
    ;                   the base address of the pointer.
    ;       string -    The string to be written.
    ;       encoding -  This refers to how the string is to be stored in the program's memory.
    ;                   UTF-8 and UTF-16 are common. Refer to the AHK manual for other encoding types.
    ;       aOffsets* - A variadic list of offsets. When using offsets the address parameter should equal the base address of the pointer.
    ;                   The address (base address) and offsets should point to the memory address which is to be written to.
    ; Return Values:
    ;       Non Zero -   Indicates success.
    ;       Zero     -   Indicates failure. Check errorLevel and A_LastError for more information
    ; Notes:
    ;       By default a null terminator is included at the end of written strings.
    ;       This behaviour is determined by the property [derivedObject].insertNullTerminator
    ;       If this property is true, then a null terminator will be included.

    writeString(address, string, encoding := "utf-8", aOffsets*)
    {
        encodingSize := (encoding = "utf-16" || encoding = "cp1200") ? 2 : 1
        requiredSize := StrPut(string, encoding) * encodingSize - (this.insertNullTerminator ? 0 : encodingSize)
        VarSetCapacity(buffer, requiredSize)
        StrPut(string, &buffer, StrLen(string) + (this.insertNullTerminator ?  1 : 0), encoding)
        return DllCall("WriteProcessMemory", "Ptr", this.hProcess, "Ptr", aOffsets.maxIndex() ? this.getAddressFromOffsets(address, aOffsets*) : address, "Ptr", &buffer, "Ptr", requiredSize, "Ptr", this.pNumberOfBytesWritten)
    }

    ; Method:   write(address, value, type := "Uint", aOffsets*)
    ;           Writes various integer type values to the process.
    ; Parameters:
    ;       address -   The memory address to which data will be written or if using the offset parameter,
    ;                   the base address of the pointer.
    ;       type    -   The integer type.
    ;                   Valid types are UChar, Char, UShort, Short, UInt, Int, Float, Int64 and Double.
    ;                   Note: Types must not contain spaces i.e. " UInt" or "UInt " will not work.
    ;                   When an invalid type is passed the method returns NULL and sets ErrorLevel to -2
    ;       aOffsets* - A variadic list of offsets. When using offsets the address parameter should equal the base address of the pointer.
    ;                   The address (base address) and offsets should point to the memory address which is to be written to.
    ; Return Values:
    ;       Non Zero -  Indicates success.
    ;       Zero     -  Indicates failure. Check errorLevel and A_LastError for more information
    ;       Null    -   An invalid type was passed. Errorlevel is set to -2

    write(address, value, type := "Uint", aOffsets*)
    {
        if !this.aTypeSize.hasKey(type)
            return "", ErrorLevel := -2
        return DllCall("WriteProcessMemory", "Ptr", this.hProcess, "Ptr", aOffsets.maxIndex() ? this.getAddressFromOffsets(address, aOffsets*) : address, type "*", value, "Ptr", this.aTypeSize[type], "Ptr", this.pNumberOfBytesWritten)
    }

    ; Method:   writeRaw(address, pBuffer, sizeBytes, aOffsets*)
    ;           Writes a buffer to the process.
    ; Parameters:
    ;   address -       The memory address to which the contents of the buffer will be written
    ;                   or if using the offset parameter, the base address of the pointer.
    ;   pBuffer -       A pointer to the buffer which is to be written.
    ;                   This does not necessarily have to be the beginning of the buffer itself e.g. pBuffer := &buffer + offset
    ;   sizeBytes -     The number of bytes which are to be written from the buffer.
    ;   aOffsets* -     A variadic list of offsets. When using offsets the address parameter should equal the base address of the pointer.
    ;                   The address (base address) and offsets should point to the memory address which is to be written to.
    ; Return Values:
    ;       Non Zero -  Indicates success.
    ;       Zero     -  Indicates failure. Check errorLevel and A_LastError for more information

    writeRaw(address, pBuffer, sizeBytes, aOffsets*)
    {
        return DllCall("WriteProcessMemory", "Ptr", this.hProcess, "Ptr", aOffsets.maxIndex() ? this.getAddressFromOffsets(address, aOffsets*) : address, "Ptr", pBuffer, "Ptr", sizeBytes, "Ptr", this.pNumberOfBytesWritten)
    }

    ; Method:   writeBytes(address, hexStringOrByteArray, aOffsets*)
    ;           Writes a sequence of byte values to the process.
    ; Parameters:
    ;   address -       The memory address to where the bytes will be written
    ;                   or if using the offset parameter, the base address of the pointer.
    ;   hexStringOrByteArray -  This can either be either a string (A) or an object/array (B) containing the values to be written.
    ;
    ;               A) HexString -      A string of hex bytes.  The '0x' hex prefix is optional.
    ;                                   Bytes can optionally be separated using the space or tab characters.
    ;                                   Each byte must be two characters in length i.e. '04' or '0x04' (not '4' or '0x4')
    ;               B) Object/Array -   An array containing hex or decimal byte values e.g. array := [10, 29, 0xA]
    ;
    ;   aOffsets* -     A variadic list of offsets. When using offsets the address parameter should equal the base address of the pointer.
    ;                   The address (base address) and offsets should point to the memory address which is to be written to.
    ; Return Values:
    ;       -1, -2, -3, -4  - Error with the hexstring. Refer to hexStringToPattern() for details.
    ;       Other Non Zero  - Indicates success.
    ;       Zero            - Indicates write failure. Check errorLevel and A_LastError for more information
    ;
    ;   Examples:
    ;                   writeBytes(0xAABBCC11, "DEADBEEF")          ; Writes the bytes DE AD BE EF starting at address  0xAABBCC11
    ;                   writeBytes(0xAABBCC11, [10, 20, 0xA, 2])

    writeBytes(address, hexStringOrByteArray, aOffsets*)
    {
        if !IsObject(hexStringOrByteArray)
        {
            if !IsObject(hexStringOrByteArray := this.hexStringToPattern(hexStringOrByteArray))
                return hexStringOrByteArray
        }
        sizeBytes := this.getNeedleFromAOBPattern("", buffer, hexStringOrByteArray*)
        return this.writeRaw(address, &buffer, sizeBytes, aOffsets*)
    }

    ; Method:           pointer(address, finalType := "UInt", offsets*)
    ;                   This is an internal method. Since the other various methods all offer this functionality, they should be used instead.
    ;                   This will read integer values of both pointers and non-pointers (i.e. a single memory address)
    ; Parameters:
    ;   address -       The base address of the pointer or the memory address for a non-pointer.
    ;   finalType -     The type of integer stored at the final address.
    ;                   Valid types are UChar, Char, UShort, Short, UInt, Int, Float, Int64 and Double.
    ;                   Note: Types must not contain spaces i.e. " UInt" or "UInt " will not work.
    ;                   When an invalid type is passed the method returns NULL and sets ErrorLevel to -2
    ;   aOffsets* -     A variadic list of offsets used to calculate the pointers final address.
    ; Return Values: (The same as the read() method)
    ;       integer -   Indicates success.
    ;       Null    -   Indicates failure. Check ErrorLevel and A_LastError for more information.
    ;       Note:       Since the returned integer value may be 0, to check for success/failure compare the result
    ;                   against null i.e. if (result = "") then an error has occurred.
    ;                   If the target application is 64bit the pointers are read as an 8 byte Int64 (this.PtrType)

    pointer(address, finalType := "UInt", offsets*)
    {
        For index, offset in offsets
            address := this.Read(address, this.ptrType) + offset
        Return this.Read(address, finalType)
    }

    ; Method:               getAddressFromOffsets(address, aOffsets*)
    ;                       Returns the final address of a pointer.
    ;                       This is an internal method used by various methods however, this method may be useful if you are
    ;                       looking to eliminate the overhead overhead associated with reading pointers which only change
    ;                       on startup or map/level change. In other words you can cache the final address and
    ;                       read from this address directly.
    ; Parameters:
    ;   address             The base address of the pointer.
    ;   aOffsets*           A variadic list of offsets used to calculate the pointers final address.
    ;                       At least one offset must be present.
    ; Return Values:
    ;   Positive integer    The final memory address pointed to by the pointer.
    ;   Negative integer    Failure
    ;   Null                Failure
    ; Note:                 If the target application is 64bit the pointers are read as an 8 byte Int64 (this.PtrType)

    getAddressFromOffsets(address, aOffsets*)
    {
        return  aOffsets.Remove() + this.pointer(address, this.ptrType, aOffsets*) ; remove the highest key so can use pointer() to find final memory address (minus the last offset)
    }

    ; Interesting note:
    ; Although handles are 64-bit pointers, only the less significant 32 bits are employed in them for the purpose
    ; of better compatibility (for example, to enable 32-bit and 64-bit processes interact with each other)
    ; Here are examples of such types: HANDLE, HWND, HMENU, HPALETTE, HBITMAP, etc.
    ; http://www.viva64.com/en/k/0005/



    ; Method:   getProcessBaseAddress(WindowTitle, windowMatchMode := 3)
    ;           Returns the base address of a process. In most cases this will provide the same result as calling getModuleBaseAddress() (when passing
    ;           a null value as the module parameter), however getProcessBaseAddress() will usually work regardless of the bitness
    ;           of both the AHK exe and the target process.
    ;           *This method relies on the target process having a window and will not work for console apps*
    ;           *'DetectHiddenWindows, On' is required for hidden windows*
    ;           ***If this returns an incorrect value, try using (the MORE RELIABLE) getModuleBaseAddress() instead.***
    ; Parameters:
    ;   windowTitle         This can be any AHK windowTitle identifier, such as
    ;                       ahk_exe, ahk_class, ahk_pid, or simply the window title. e.g. "ahk_exe calc.exe" or "Calculator".
    ;                       It's safer not to use the window title, as some things can have the same window title e.g. an open folder called "Starcraft II"
    ;                       would have the same window title as the game itself.
    ;   windowMatchMode     Determines the matching mode used when finding the program's window (windowTitle).
    ;                       The default value is 3 i.e. an exact match. The current matchmode will be used if the parameter is null or 0.
    ;                       Refer to AHK's setTitleMathMode for more information.
    ; Return Values:
    ;   Positive integer    The base address of the process (success).
    ;   Null                The process's window couldn't be found.
    ;   0                   The GetWindowLong or GetWindowLongPtr call failed. Try getModuleBaseAddress() instead.


    getProcessBaseAddress(windowTitle, windowMatchMode := "3")
    {
        if (windowMatchMode && A_TitleMatchMode != windowMatchMode)
        {
            mode := A_TitleMatchMode ; This is a string and will not contain the 0x prefix
            StringReplace, windowMatchMode, windowMatchMode, 0x ; remove hex prefix as SetTitleMatchMode will throw a run time error. This will occur if integer mode is set to hex and matchmode param is passed as an number not a string.
            SetTitleMatchMode, %windowMatchMode%    ;mode 3 is an exact match
        }
        WinGet, hWnd, ID, %WindowTitle%
        if mode
            SetTitleMatchMode, %mode%    ; In case executed in autoexec
        if !hWnd
            return ; return blank failed to find window
       ; GetWindowLong returns a Long (Int) and GetWindowLongPtr return a Long_Ptr
        return DllCall(A_PtrSize = 4     ; If DLL call fails, returned value will = 0
            ? "GetWindowLong"
            : "GetWindowLongPtr"
            , "Ptr", hWnd, "Int", -6, A_Is64bitOS ? "Int64" : "UInt")
            ; For the returned value when the OS is 64 bit use Int64 to prevent negative overflow when AHK is 32 bit and target process is 64bit
            ; however if the OS is 32 bit, must use UInt, otherwise the number will be huge (however it will still work as the lower 4 bytes are correct)
            ; Note - it's the OS bitness which matters here, not the scripts/AHKs
    }

    ; http://winprogger.com/getmodulefilenameex-enumprocessmodulesex-failures-in-wow64/
    ; http://stackoverflow.com/questions/3801517/how-to-enum-modules-in-a-64bit-process-from-a-32bit-wow-process

    ; Method:            getModuleBaseAddress(module := "", byRef aModuleInfo := "")
    ; Parameters:
    ;   moduleName -    The file name of the module/dll to find e.g. "calc.exe", "GDI32.dll", "Bass.dll" etc
    ;                   If no module (null) is specified, the address of the base module - main()/process will be returned
    ;                   e.g. for calc.exe the following two method calls are equivalent getModuleBaseAddress() and getModuleBaseAddress("calc.exe")
    ;   aModuleInfo -   (Optional) A module Info object is returned in this variable. If method fails this variable is made blank.
    ;                   This object contains the keys: name, fileName, lpBaseOfDll, SizeOfImage, and EntryPoint
    ; Return Values:
    ;   Positive integer - The module's base/load address (success).
    ;   -1 - Module not found
    ;   -3 - EnumProcessModulesEx failed
    ;   -4 - The AHK script is 32 bit and you are trying to access the modules of a 64 bit target process. Or the target process has been closed.
    ; Notes:    A 64 bit AHK can enumerate the modules of a target 64 or 32 bit process.
    ;           A 32 bit AHK can only enumerate the modules of a 32 bit process
    ;           This method requires PROCESS_QUERY_INFORMATION + PROCESS_VM_READ access rights. These are included by default with this class.

    getModuleBaseAddress(moduleName := "", byRef aModuleInfo := "")
    {
        aModuleInfo := ""
        if (moduleName = "")
            moduleName := this.GetModuleFileNameEx(0, True) ; main executable module of the process - get just fileName no path
        if r := this.getModules(aModules, True) < 0
            return r ; -4, -3
        return aModules.HasKey(moduleName) ? (aModules[moduleName].lpBaseOfDll, aModuleInfo := aModules[moduleName]) : -1
        ; no longer returns -5 for failed to get module info
    }


    ; Method:                   getModuleFromAddress(address, byRef aModuleInfo)
    ;                           Finds the module in which the address resides.
    ; Parameters:
    ;   address                 The address of interest.
    ;
    ;   aModuleInfo             (Optional) An unquoted variable name. If the module associated with the address is found,
    ;                           a moduleInfo object will be stored in this variable. This object has the
    ;                           following keys: name, fileName, lpBaseOfDll, SizeOfImage, and EntryPoint.
    ;                           If the address is not found to reside inside a module, the passed variable is
    ;                           made blank/null.
    ;   offsetFromModuleBase    (Optional) Stores the relative offset from the module base address
    ;                           to the specified address. If the method fails then the passed variable is set to blank/empty.
    ; Return Values:
    ;   1                       Success - The address is contained within a module.
    ;   -1                      The specified address does not reside within a loaded module.
    ;   -3                      EnumProcessModulesEx failed.
    ;   -4                      The AHK script is 32 bit and you are trying to access the modules of a 64 bit target process.

    getModuleFromAddress(address, byRef aModuleInfo, byRef offsetFromModuleBase := "")
    {
        aModuleInfo := offsetFromModule := ""
        if result := this.getmodules(aModules) < 0
            return result ; error -3, -4
        for k, module in aModules
        {
            if (address >= module.lpBaseOfDll && address < module.lpBaseOfDll + module.SizeOfImage)
                return 1, aModuleInfo := module, offsetFromModuleBase := address - module.lpBaseOfDll
        }
        return -1
    }

    ; SeDebugPrivileges is required to read/write memory in some programs.
    ; This only needs to be called once when the script starts,
    ; regardless of the number of programs being read (or if the target programs restart)
    ; Call this before attempting to call any other methods in this class
    ; i.e. call _ClassMemory.setSeDebugPrivilege() at the very start of the script.

    setSeDebugPrivilege(enable := True)
    {
        h := DllCall("OpenProcess", "UInt", 0x0400, "Int", false, "UInt", DllCall("GetCurrentProcessId"), "Ptr")
        ; Open an adjustable access token with this process (TOKEN_ADJUST_PRIVILEGES = 32)
        DllCall("Advapi32.dll\OpenProcessToken", "Ptr", h, "UInt", 32, "PtrP", t)
        VarSetCapacity(ti, 16, 0)  ; structure of privileges
        NumPut(1, ti, 0, "UInt")  ; one entry in the privileges array...
        ; Retrieves the locally unique identifier of the debug privilege:
        DllCall("Advapi32.dll\LookupPrivilegeValue", "Ptr", 0, "Str", "SeDebugPrivilege", "Int64P", luid)
        NumPut(luid, ti, 4, "Int64")
        if enable
            NumPut(2, ti, 12, "UInt")  ; enable this privilege: SE_PRIVILEGE_ENABLED = 2
        ; Update the privileges of this process with the new access token:
        r := DllCall("Advapi32.dll\AdjustTokenPrivileges", "Ptr", t, "Int", false, "Ptr", &ti, "UInt", 0, "Ptr", 0, "Ptr", 0)
        DllCall("CloseHandle", "Ptr", t)  ; close this access token handle to save memory
        DllCall("CloseHandle", "Ptr", h)  ; close this process handle to save memory
        return r
    }


    ; Method:  isTargetProcess64Bit(PID, hProcess := "", currentHandleAccess := "")
    ;          Determines if a process is 64 bit.
    ; Parameters:
    ;   PID                     The Process ID of the target process. If required this is used to open a temporary process handle.
    ;   hProcess                (Optional) A handle to the process, as returned by openProcess() i.e. [derivedObject].hProcess
    ;   currentHandleAccess     (Optional) The dwDesiredAccess value used when opening the process handle which has been
    ;                           passed as the hProcess parameter. If specifying hProcess, you should also specify this value.
    ; Return Values:
    ;   True    The target application is 64 bit.
    ;   False   The target application is 32 bit.
    ;   Null    The method failed.
    ; Notes:
    ;   This is an internal method which is called when the new operator is used. It is used to set the pointer type for 32/64 bit applications so the pointer methods will work.
    ;   This operation requires a handle with PROCESS_QUERY_INFORMATION or PROCESS_QUERY_LIMITED_INFORMATION access rights.
    ;   If the currentHandleAccess parameter does not contain these rights (or not passed) or if the hProcess (process handle) is invalid (or not passed)
    ;   a temporary handle is opened to perform this operation. Otherwise if hProcess and currentHandleAccess appear valid
    ;   the passed hProcess is used to perform the operation.

    isTargetProcess64Bit(PID, hProcess := "", currentHandleAccess := "")
    {
        if !A_Is64bitOS
            return False
        ; If insufficient rights, open a temporary handle
        else if !hProcess || !(currentHandleAccess & (this.aRights.PROCESS_QUERY_INFORMATION | this.aRights.PROCESS_QUERY_LIMITED_INFORMATION))
            closeHandle := hProcess := this.openProcess(PID, this.aRights.PROCESS_QUERY_INFORMATION)
        if (hProcess && DllCall("IsWow64Process", "Ptr", hProcess, "Int*", Wow64Process))
            result := !Wow64Process
        return result, closeHandle ? this.CloseHandle(hProcess) : ""
    }
    /*
        _Out_  PBOOL Wow64Proces value set to:
        True if the process is running under WOW64 - 32bit app on 64bit OS.
        False if the process is running under 32-bit Windows!
        False if the process is a 64-bit application running under 64-bit Windows.
    */

    ; Method: suspend() / resume()
    ; Notes:
    ;   These are undocumented Windows functions which suspend and resume the process. Here be dragons.
    ;   The process handle must have PROCESS_SUSPEND_RESUME access rights.
    ;   That is, you must specify this when using the new operator, as it is not included.
    ;   Some people say it requires more rights and just use PROCESS_ALL_ACCESS, however PROCESS_SUSPEND_RESUME has worked for me.
    ;   Suspending a process manually can be quite helpful when reversing memory addresses and pointers, although it's not at all required.
    ;   As an unorthodox example, memory addresses holding pointers are often stored in a slightly obfuscated manner i.e. they require bit operations to calculate their
    ;   true stored value (address). This obfuscation can prevent Cheat Engine from finding the true origin of a pointer or links to other memory regions. If there
    ;   are no static addresses between the obfuscated address and the final destination address then CE wont find anything (there are ways around this in CE). One way around this is to
    ;   suspend the process, write the true/deobfuscated value to the address and then perform your scans. Afterwards write back the original values and resume the process.

    suspend()
    {
        return DllCall("ntdll\NtSuspendProcess", "Ptr", this.hProcess)
    }

    resume()
    {
        return DllCall("ntdll\NtResumeProcess", "Ptr", this.hProcess)
    }

    ; Method:               getModules(byRef aModules, useFileNameAsKey := False)
    ;                       Stores the process's loaded modules as an array of (object) modules in the aModules parameter.
    ; Parameters:
    ;   aModules            An unquoted variable name. The loaded modules of the process are stored in this variable as an array of objects.
    ;                       Each object in this array has the following keys: name, fileName, lpBaseOfDll, SizeOfImage, and EntryPoint.
    ;   useFileNameAsKey    When true, the file name e.g. GDI32.dll is used as the lookup key for each module object.
    ; Return Values:
    ;   Positive integer    The size of the aModules array. (Success)
    ;   -3                  EnumProcessModulesEx failed.
    ;   -4                  The AHK script is 32 bit and you are trying to access the modules of a 64 bit target process.

    getModules(byRef aModules, useFileNameAsKey := False)
    {
        if (A_PtrSize = 4 && this.IsTarget64bit)
            return -4 ; AHK is 32bit and target process is 64 bit, this function wont work
        aModules := []
        if !moduleCount := this.EnumProcessModulesEx(lphModule)
            return -3
        loop % moduleCount
        {
            this.GetModuleInformation(hModule := numget(lphModule, (A_index - 1) * A_PtrSize), aModuleInfo)
            aModuleInfo.Name := this.GetModuleFileNameEx(hModule)
            filePath := aModuleInfo.name
            SplitPath, filePath, fileName
            aModuleInfo.fileName := fileName
            if useFileNameAsKey
                aModules[fileName] := aModuleInfo
            else aModules.insert(aModuleInfo)
        }
        return moduleCount
    }



    getEndAddressOfLastModule(byRef aModuleInfo := "")
    {
        if !moduleCount := this.EnumProcessModulesEx(lphModule)
            return -3
        hModule := numget(lphModule, (moduleCount - 1) * A_PtrSize)
        if this.GetModuleInformation(hModule, aModuleInfo)
            return aModuleInfo.lpBaseOfDll + aModuleInfo.SizeOfImage
        return -5
    }

    ; lpFilename [out]
    ; A pointer to a buffer that receives the fully qualified path to the module.
    ; If the size of the file name is larger than the value of the nSize parameter, the function succeeds
    ; but the file name is truncated and null-terminated.
    ; If the buffer is adequate the string is still null terminated.

    GetModuleFileNameEx(hModule := 0, fileNameNoPath := False)
    {
        ; ANSI MAX_PATH = 260 (includes null) - unicode can be ~32K.... but no one would ever have one that size
        ; So just give it a massive size and don't bother checking. Most coders just give it MAX_PATH size anyway
        VarSetCapacity(lpFilename, 2048 * (A_IsUnicode ? 2 : 1))
        DllCall("psapi\GetModuleFileNameEx"
                    , "Ptr", this.hProcess
                    , "Ptr", hModule
                    , "Str", lpFilename
                    , "Uint", 2048 / (A_IsUnicode ? 2 : 1))
        if fileNameNoPath
            SplitPath, lpFilename, lpFilename ; strips the path so = GDI32.dll

        return lpFilename
    }

    ; dwFilterFlag
    ;   LIST_MODULES_DEFAULT    0x0
    ;   LIST_MODULES_32BIT      0x01
    ;   LIST_MODULES_64BIT      0x02
    ;   LIST_MODULES_ALL        0x03
    ; If the function is called by a 32-bit application running under WOW64, the dwFilterFlag option
    ; is ignored and the function provides the same results as the EnumProcessModules function.
    EnumProcessModulesEx(byRef lphModule, dwFilterFlag := 0x03)
    {
        lastError := A_LastError
        size := VarSetCapacity(lphModule, 4)
        loop
        {
            DllCall("psapi\EnumProcessModulesEx"
                        , "Ptr", this.hProcess
                        , "Ptr", &lphModule
                        , "Uint", size
                        , "Uint*", reqSize
                        , "Uint", dwFilterFlag)
            if ErrorLevel
                return 0
            else if (size >= reqSize)
                break
            else size := VarSetCapacity(lphModule, reqSize)
        }
        ; On first loop it fails with A_lastError = 0x299 as its meant to
        ; might as well reset it to its previous version
        DllCall("SetLastError", "UInt", lastError)
        return reqSize // A_PtrSize ; module count  ; sizeof(HMODULE) - enumerate the array of HMODULEs
    }

    GetModuleInformation(hModule, byRef aModuleInfo)
    {
        VarSetCapacity(MODULEINFO, A_PtrSize * 3), aModuleInfo := []
        return DllCall("psapi\GetModuleInformation"
                    , "Ptr", this.hProcess
                    , "Ptr", hModule
                    , "Ptr", &MODULEINFO
                    , "UInt", A_PtrSize * 3)
                , aModuleInfo := {  lpBaseOfDll: numget(MODULEINFO, 0, "Ptr")
                                ,   SizeOfImage: numget(MODULEINFO, A_PtrSize, "UInt")
                                ,   EntryPoint: numget(MODULEINFO, A_PtrSize * 2, "Ptr") }
    }

    ; Method:           hexStringToPattern(hexString)
    ;                   Converts the hex string parameter into an array of bytes pattern (AOBPattern) that
    ;                   can be passed to the various pattern scan methods i.e.  modulePatternScan(), addressPatternScan(), rawPatternScan(), and processPatternScan()
    ;
    ; Parameters:
    ;   hexString -     A string of hex bytes.  The '0x' hex prefix is optional.
    ;                   Bytes can optionally be separated using the space or tab characters.
    ;                   Each byte must be two characters in length i.e. '04' or '0x04' (not '4' or '0x4')
    ;                   ** Unlike the other methods, wild card bytes MUST be denoted using '??' (two question marks)**
    ;
    ; Return Values:
    ;   Object          Success - The returned object contains the AOB pattern.
    ;   -1              An empty string was passed.
    ;   -2              Non hex character present.  Acceptable characters are A-F, a-F, 0-9, ?, space, tab, and 0x (hex prefix).
    ;   -3              Non-even wild card character count. One of the wild card bytes is missing a '?' e.g. '?' instead of '??'.
    ;   -4              Non-even character count. One of the hex bytes is probably missing a character e.g. '4' instead of '04'.
    ;
    ;   Examples:
    ;                   pattern := hexStringToPattern("DEADBEEF02")
    ;                   pattern := hexStringToPattern("0xDE0xAD0xBE0xEF0x02")
    ;                   pattern := hexStringToPattern("DE AD BE EF 02")
    ;                   pattern := hexStringToPattern("0xDE 0xAD 0xBE 0xEF 0x02")
    ;
    ;                   This will mark the third byte as wild:
    ;                   pattern := hexStringToPattern("DE AD ?? EF 02")
    ;                   pattern := hexStringToPattern("0xDE 0xAD ?? 0xEF 0x02")
    ;
    ;                   The returned pattern can then be passed to the various pattern scan methods, for example:
    ;                   pattern := hexStringToPattern("DE AD BE EF 02")
    ;                   memObject.processPatternScan(,, pattern*)   ; Note the '*'

    hexStringToPattern(hexString)
    {
        AOBPattern := []
        hexString := RegExReplace(hexString, "(\s|0x)")
        StringReplace, hexString, hexString, ?, ?, UseErrorLevel
        wildCardCount := ErrorLevel

        if !length := StrLen(hexString)
            return -1 ; no str
        else if RegExMatch(hexString, "[^0-9a-fA-F?]")
            return -2 ; non hex character and not a wild card
        else if Mod(wildCardCount, 2)
            return -3 ; non-even wild card character count
        else if Mod(length, 2)
            return -4 ; non-even character count
        loop, % length/2
        {
            value := "0x" SubStr(hexString, 1 + 2 * (A_index-1), 2)
            AOBPattern.Insert(value + 0 = "" ? "?" : value)
        }
        return AOBPattern
    }

    ; Method:           stringToPattern(string, encoding := "UTF-8", insertNullTerminator := False)
    ;                   Converts a text string parameter into an array of bytes pattern (AOBPattern) that
    ;                   can be passed to the various pattern scan methods i.e.  modulePatternScan(), addressPatternScan(), rawPatternScan(), and processPatternScan()
    ;
    ; Parameters:
    ;   string                  The text string to convert.
    ;   encoding                This refers to how the string is stored in the program's memory.
    ;                           UTF-8 and UTF-16 are common. Refer to the AHK manual for other encoding types.
    ;   insertNullTerminator    Includes the null terminating byte(s) (at the end of the string) in the AOB pattern.
    ;                           This should be set to 'false' unless you are certain that the target string is null terminated and you are searching for the entire string or the final part of the string.
    ;
    ; Return Values:
    ;   Object          Success - The returned object contains the AOB pattern.
    ;   -1              An empty string was passed.
    ;
    ;   Examples:
    ;                   pattern := stringToPattern("This text exists somewhere in the target program!")
    ;                   memObject.processPatternScan(,, pattern*)   ; Note the '*'

    stringToPattern(string, encoding := "UTF-8", insertNullTerminator := False)
    {
        if !length := StrLen(string)
            return -1 ; no str
        AOBPattern := []
        encodingSize := (encoding = "utf-16" || encoding = "cp1200") ? 2 : 1
        requiredSize := StrPut(string, encoding) * encodingSize - (insertNullTerminator ? 0 : encodingSize)
        VarSetCapacity(buffer, requiredSize)
        StrPut(string, &buffer, length + (insertNullTerminator ?  1 : 0), encoding)
        loop, % requiredSize
            AOBPattern.Insert(NumGet(buffer, A_Index-1, "UChar"))
        return AOBPattern
    }


    ; Method:           modulePatternScan(module := "", aAOBPattern*)
    ;                   Scans the specified module for the specified array of bytes
    ; Parameters:
    ;   module -        The file name of the module/dll to search e.g. "calc.exe", "GDI32.dll", "Bass.dll" etc
    ;                   If no module (null) is specified, the executable file of the process will be used.
    ;                   e.g. for calc.exe it would be the same as calling modulePatternScan(, aAOBPattern*) or modulePatternScan("calc.exe", aAOBPattern*)
    ;   aAOBPattern*    A variadic list of byte values i.e. the array of bytes to find.
    ;                   Wild card bytes should be indicated by passing a non-numeric value eg "?".
    ; Return Values:
    ;   Positive int    Success. The memory address of the found pattern.
    ;   Null            Failed to find or retrieve the specified module. ErrorLevel is set to the returned error from getModuleBaseAddress()
    ;                   refer to that method for more information.
    ;   0               The pattern was not found inside the module
    ;   -9              VirtualQueryEx() failed
    ;   -10             The aAOBPattern* is invalid. No bytes were passed

    modulePatternScan(module := "", aAOBPattern*)
    {
        MEM_COMMIT := 0x1000, MEM_MAPPED := 0x40000, MEM_PRIVATE := 0x20000
        , PAGE_NOACCESS := 0x01, PAGE_GUARD := 0x100

        if (result := this.getModuleBaseAddress(module, aModuleInfo)) <= 0
             return "", ErrorLevel := result ; failed
        if !patternSize := this.getNeedleFromAOBPattern(patternMask, AOBBuffer, aAOBPattern*)
            return -10 ; no pattern
        ; Try to read the entire module in one RPM()
        ; If fails with access (-1) iterate the modules memory pages and search the ones which are readable
        if (result := this.PatternScan(aModuleInfo.lpBaseOfDll, aModuleInfo.SizeOfImage, patternMask, AOBBuffer)) >= 0
            return result  ; Found / not found
        ; else RPM() failed lets iterate the pages
        address := aModuleInfo.lpBaseOfDll
        endAddress := address + aModuleInfo.SizeOfImage
        loop
        {
            if !this.VirtualQueryEx(address, aRegion)
                return -9
            if (aRegion.State = MEM_COMMIT
            && !(aRegion.Protect & (PAGE_NOACCESS | PAGE_GUARD)) ; can't read these areas
            ;&& (aRegion.Type = MEM_MAPPED || aRegion.Type = MEM_PRIVATE) ;Might as well read Image sections as well
            && aRegion.RegionSize >= patternSize
            && (result := this.PatternScan(address, aRegion.RegionSize, patternMask, AOBBuffer)) > 0)
                return result
        } until (address += aRegion.RegionSize) >= endAddress
        return 0
    }

    ; Method:               addressPatternScan(startAddress, sizeOfRegionBytes, aAOBPattern*)
    ;                       Scans a specified memory region for an array of bytes pattern.
    ;                       The entire memory area specified must be readable for this method to work,
    ;                       i.e. you must ensure the area is readable before calling this method.
    ; Parameters:
    ;   startAddress        The memory address from which to begin the search.
    ;   sizeOfRegionBytes   The numbers of bytes to scan in the memory region.
    ;   aAOBPattern*        A variadic list of byte values i.e. the array of bytes to find.
    ;                       Wild card bytes should be indicated by passing a non-numeric value eg "?".
    ; Return Values:
    ;   Positive integer    Success. The memory address of the found pattern.
    ;   0                   Pattern not found
    ;   -1                  Failed to read the memory region.
    ;   -10                 An aAOBPattern pattern. No bytes were passed.

    addressPatternScan(startAddress, sizeOfRegionBytes, aAOBPattern*)
    {
        if !this.getNeedleFromAOBPattern(patternMask, AOBBuffer, aAOBPattern*)
            return -10
        return this.PatternScan(startAddress, sizeOfRegionBytes, patternMask, AOBBuffer)
    }

    ; Method:       processPatternScan(startAddress := 0, endAddress := "", aAOBPattern*)
    ;               Scan the memory space of the current process for an array of bytes pattern.
    ;               To use this in a loop (scanning for multiple occurrences of the same pattern),
    ;               simply call it again passing the last found address + 1 as the startAddress.
    ; Parameters:
    ;   startAddress -      The memory address from which to begin the search.
    ;   endAddress -        The memory address at which the search ends.
    ;                       Defaults to 0x7FFFFFFF for 32 bit target processes.
    ;                       Defaults to 0xFFFFFFFF for 64 bit target processes when the AHK script is 32 bit.
    ;                       Defaults to 0x7FFFFFFFFFF for 64 bit target processes when the AHK script is 64 bit.
    ;                       0x7FFFFFFF and 0x7FFFFFFFFFF are the maximum process usable virtual address spaces for 32 and 64 bit applications.
    ;                       Anything higher is used by the system (unless /LARGEADDRESSAWARE and 4GT have been modified).
    ;                       Note: The entire pattern must be occur inside this range for a match to be found. The range is inclusive.
    ;   aAOBPattern* -      A variadic list of byte values i.e. the array of bytes to find.
    ;                       Wild card bytes should be indicated by passing a non-numeric value eg "?".
    ; Return Values:
    ;   Positive integer -  Success. The memory address of the found pattern.
    ;   0                   The pattern was not found.
    ;   -1                  VirtualQueryEx() failed.
    ;   -2                  Failed to read a memory region.
    ;   -10                 The aAOBPattern* is invalid. (No bytes were passed)

    processPatternScan(startAddress := 0x00000000, endAddress := 0x7FFFFFFF, aAOBPattern*)
    {
        address := startAddress
        if endAddress is not integer
            endAddress := this.isTarget64bit ? (A_PtrSize = 8 ? 0x7FFFFFFFFFF : 0xFFFFFFFF) : 0x7FFFFFFF

        MEM_COMMIT := 0x1000, MEM_MAPPED := 0x40000, MEM_PRIVATE := 0x20000
        PAGE_NOACCESS := 0x01, PAGE_GUARD := 0x100
        if !patternSize := this.getNeedleFromAOBPattern(patternMask, AOBBuffer, aAOBPattern*)
            return -10
        while address <= endAddress ; > 0x7FFFFFFF - definitely reached the end of the useful area (at least for a 32 target process)
        {
            if !this.VirtualQueryEx(address, aInfo)
                return -1
            if A_Index = 1
                aInfo.RegionSize -= address - aInfo.BaseAddress
            if (aInfo.State = MEM_COMMIT)
            && !(aInfo.Protect & (PAGE_NOACCESS | PAGE_GUARD)) ; can't read these areas
            ;&& (aInfo.Type = MEM_MAPPED || aInfo.Type = MEM_PRIVATE) ;Might as well read Image sections as well
            && aInfo.RegionSize >= patternSize
            && (result := this.PatternScan(address, aInfo.RegionSize, patternMask, AOBBuffer))
            {
                if result < 0
                    return -2
                else if (result + patternSize - 1 <= endAddress)
                    return result
                else return 0
            }
            address += aInfo.RegionSize
        }
        return 0
    }

    ; Method:           rawPatternScan(byRef buffer, sizeOfBufferBytes := "", aAOBPattern*)
    ;                   Scans a binary buffer for an array of bytes pattern.
    ;                   This is useful if you have already dumped a region of memory via readRaw()
    ; Parameters:
    ;   buffer              The binary buffer to be searched.
    ;   sizeOfBufferBytes   The size of the binary buffer. If null or 0 the size is automatically retrieved.
    ;   startOffset         The offset from the start of the buffer from which to begin the search. This must be >= 0.
    ;   aAOBPattern*        A variadic list of byte values i.e. the array of bytes to find.
    ;                       Wild card bytes should be indicated by passing a non-numeric value eg "?".
    ; Return Values:
    ;   >= 0                The offset of the pattern relative to the start of the haystack.
    ;   -1                  Not found.
    ;   -2                  Parameter incorrect.

    rawPatternScan(byRef buffer, sizeOfBufferBytes := "", startOffset := 0, aAOBPattern*)
    {
        if !this.getNeedleFromAOBPattern(patternMask, AOBBuffer, aAOBPattern*)
            return -10
        if (sizeOfBufferBytes + 0 = "" || sizeOfBufferBytes <= 0)
            sizeOfBufferBytes := VarSetCapacity(buffer)
        if (startOffset + 0 = "" || startOffset < 0)
            startOffset := 0
        return this.bufferScanForMaskedPattern(&buffer, sizeOfBufferBytes, patternMask, &AOBBuffer, startOffset)
    }

    ; Method:           getNeedleFromAOBPattern(byRef patternMask, byRef needleBuffer, aAOBPattern*)
    ;                   Converts an array of bytes pattern (aAOBPattern*) into a binary needle and pattern mask string
    ;                   which are compatible with patternScan() and bufferScanForMaskedPattern().
    ;                   The modulePatternScan(), addressPatternScan(), rawPatternScan(), and processPatternScan() methods
    ;                   allow you to directly search for an array of bytes pattern in a single method call.
    ; Parameters:
    ;   patternMask -   (output) A string which indicates which bytes are wild/non-wild.
    ;   needleBuffer -  (output) The array of bytes passed via aAOBPattern* is converted to a binary needle and stored inside this variable.
    ;   aAOBPattern* -  (input) A variadic list of byte values i.e. the array of bytes from which to create the patternMask and needleBuffer.
    ;                   Wild card bytes should be indicated by passing a non-numeric value eg "?".
    ; Return Values:
    ;  The number of bytes in the binary needle and hence the number of characters in the patternMask string.

    getNeedleFromAOBPattern(byRef patternMask, byRef needleBuffer, aAOBPattern*)
    {
        patternMask := "", VarSetCapacity(needleBuffer, aAOBPattern.MaxIndex())
        for i, v in aAOBPattern
            patternMask .= (v + 0 = "" ? "?" : "x"), NumPut(round(v), needleBuffer, A_Index - 1, "UChar")
        return round(aAOBPattern.MaxIndex())
    }

    ; The handle must have been opened with the PROCESS_QUERY_INFORMATION access right
    VirtualQueryEx(address, byRef aInfo)
    {

        if (aInfo.__Class != "_ClassMemory._MEMORY_BASIC_INFORMATION")
            aInfo := new this._MEMORY_BASIC_INFORMATION()
        return aInfo.SizeOfStructure = DLLCall("VirtualQueryEx"
                                                , "Ptr", this.hProcess
                                                , "Ptr", address
                                                , "Ptr", aInfo.pStructure
                                                , "Ptr", aInfo.SizeOfStructure
                                                , "Ptr")
    }

    /*
    // The c++ function used to generate the machine code
    int scan(unsigned char* haystack, unsigned int haystackSize, unsigned char* needle, unsigned int needleSize, char* patternMask, unsigned int startOffset)
    {
        for (unsigned int i = startOffset; i <= haystackSize - needleSize; i++)
        {
            for (unsigned int j = 0; needle[j] == haystack[i + j] || patternMask[j] == '?'; j++)
            {
                if (j + 1 == needleSize)
                    return i;
            }
        }
        return -1;
    }
    */

    ; Method:               PatternScan(startAddress, sizeOfRegionBytes, patternMask, byRef needleBuffer)
    ;                       Scans a specified memory region for a binary needle pattern using a machine code function
    ;                       If found it returns the memory address of the needle in the processes memory.
    ; Parameters:
    ;   startAddress -      The memory address from which to begin the search.
    ;   sizeOfRegionBytes - The numbers of bytes to scan in the memory region.
    ;   patternMask -       This string indicates which bytes must match and which bytes are wild. Each wildcard byte must be denoted by a single '?'.
    ;                       Non wildcards can use any other single character e.g 'x'. There should be no spaces.
    ;                       With the patternMask 'xx??x', the first, second, and fifth bytes must match. The third and fourth bytes are wild.
    ;    needleBuffer -     The variable which contains the binary needle. This needle should consist of UChar bytes.
    ; Return Values:
    ;   Positive integer    The address of the pattern.
    ;   0                   Pattern not found.
    ;   -1                  Failed to read the region.

    patternScan(startAddress, sizeOfRegionBytes, byRef patternMask, byRef needleBuffer)
    {
        if !this.readRaw(startAddress, buffer, sizeOfRegionBytes)
            return -1
        if (offset := this.bufferScanForMaskedPattern(&buffer, sizeOfRegionBytes, patternMask, &needleBuffer)) >= 0
            return startAddress + offset
        else return 0
    }
    ; Method:               bufferScanForMaskedPattern(byRef hayStack, sizeOfHayStackBytes, byRef patternMask, byRef needle)
    ;                       Scans a binary haystack for binary needle against a pattern mask string using a machine code function.
    ; Parameters:
    ;   hayStackAddress -   The address of the binary haystack which is to be searched.
    ;   sizeOfHayStackBytes The total size of the haystack in bytes.
    ;   patternMask -       A string which indicates which bytes must match and which bytes are wild. Each wildcard byte must be denoted by a single '?'.
    ;                       Non wildcards can use any other single character e.g 'x'. There should be no spaces.
    ;                       With the patternMask 'xx??x', the first, second, and fifth bytes must match. The third and fourth bytes are wild.
    ;   needleAddress -     The address of the binary needle to find. This needle should consist of UChar bytes.
    ;   startOffset -       The offset from the start of the haystack from which to begin the search. This must be >= 0.
    ; Return Values:
    ;   >= 0                Found. The pattern begins at this offset - relative to the start of the haystack.
    ;   -1                  Not found.
    ;   -2                  Invalid sizeOfHayStackBytes parameter - Must be > 0.

    ; Notes:
    ;       This is a basic function with few safeguards. Incorrect parameters may crash the script.

    bufferScanForMaskedPattern(hayStackAddress, sizeOfHayStackBytes, byRef patternMask, needleAddress, startOffset := 0)
    {
        static p
        if !p
        {
            if A_PtrSize = 4
                p := this.MCode("1,x86:8B44240853558B6C24182BC5568B74242489442414573BF0773E8B7C241CBB010000008B4424242BF82BD8EB038D49008B54241403D68A0C073A0A740580383F750B8D0C033BCD74174240EBE98B442424463B74241876D85F5E5D83C8FF5BC35F8BC65E5D5BC3")
            else
                p := this.MCode("1,x64:48895C2408488974241048897C2418448B5424308BF2498BD8412BF1488BF9443BD6774A4C8B5C24280F1F800000000033C90F1F400066660F1F840000000000448BC18D4101418D4AFF03C80FB60C3941380C18740743803C183F7509413BC1741F8BC8EBDA41FFC2443BD676C283C8FF488B5C2408488B742410488B7C2418C3488B5C2408488B742410488B7C2418418BC2C3")
        }
        if (needleSize := StrLen(patternMask)) + startOffset > sizeOfHayStackBytes
            return -1 ; needle can't exist inside this region. And basic check to prevent wrap around error of the UInts in the machine function
        if (sizeOfHayStackBytes > 0)
            return DllCall(p, "Ptr", hayStackAddress, "UInt", sizeOfHayStackBytes, "Ptr", needleAddress, "UInt", needleSize, "AStr", patternMask, "UInt", startOffset, "cdecl int")
        return -2
    }

    ; Notes:
    ; Other alternatives for non-wildcard buffer comparison.
    ; Use memchr to find the first byte, then memcmp to compare the remainder of the buffer against the needle and loop if it doesn't match
    ; The function FindMagic() by Lexikos uses this method.
    ; Use scanInBuf() machine code function - but this only supports 32 bit ahk. I could check if needle contains wild card and AHK is 32bit,
    ; then call this function. But need to do a speed comparison to see the benefits, but this should be faster. Although the benefits for
    ; the size of the memory regions be dumped would most likely be inconsequential as it's already extremely fast.

    MCode(mcode)
    {
        static e := {1:4, 2:1}, c := (A_PtrSize=8) ? "x64" : "x86"
        if !regexmatch(mcode, "^([0-9]+),(" c ":|.*?," c ":)([^,]+)", m)
            return
        if !DllCall("crypt32\CryptStringToBinary", "str", m3, "uint", 0, "uint", e[m1], "ptr", 0, "uint*", s, "ptr", 0, "ptr", 0)
            return
        p := DllCall("GlobalAlloc", "uint", 0, "ptr", s, "ptr")
        ; if (c="x64") ; Virtual protect must always be enabled for both 32 and 64 bit. If DEP is set to all applications (not just systems), then this is required
        DllCall("VirtualProtect", "ptr", p, "ptr", s, "uint", 0x40, "uint*", op)
        if DllCall("crypt32\CryptStringToBinary", "str", m3, "uint", 0, "uint", e[m1], "ptr", p, "uint*", s, "ptr", 0, "ptr", 0)
            return p
        DllCall("GlobalFree", "ptr", p)
        return
    }

    ; This link indicates that the _MEMORY_BASIC_INFORMATION32/64 should be based on the target process
    ; http://stackoverflow.com/questions/20068219/readprocessmemory-on-a-64-bit-proces-always-returns-error-299
    ; The msdn documentation is unclear, and suggests that a debugger can pass either structure - perhaps there is some other step involved.
    ; My tests seem to indicate that you must pass _MEMORY_BASIC_INFORMATION i.e. structure is relative to the AHK script bitness.
    ; Another post on the net also agrees with my results.

    ; Notes:
    ; A 64 bit AHK script can call this on a target 64 bit process. Issues may arise at extremely high memory addresses as AHK does not support UInt64 (but these addresses should never be used anyway).
    ; A 64 bit AHK can call this on a 32 bit target and it should work.
    ; A 32 bit AHk script can call this on a 64 bit target and it should work providing the addresses fall inside the 32 bit range.

    class _MEMORY_BASIC_INFORMATION
    {
        __new()
        {
            if !this.pStructure := DllCall("GlobalAlloc", "UInt", 0, "Ptr", this.SizeOfStructure := A_PtrSize = 8 ? 48 : 28, "Ptr")
                return ""
            return this
        }
        __Delete()
        {
            DllCall("GlobalFree", "Ptr", this.pStructure)
        }
        ; For 64bit the int64 should really be unsigned. But AHK doesn't support these
        ; so this won't work correctly for higher memory address areas
        __get(key)
        {
            static aLookUp := A_PtrSize = 8
                                ?   {   "BaseAddress": {"Offset": 0, "Type": "Int64"}
                                    ,    "AllocationBase": {"Offset": 8, "Type": "Int64"}
                                    ,    "AllocationProtect": {"Offset": 16, "Type": "UInt"}
                                    ,    "RegionSize": {"Offset": 24, "Type": "Int64"}
                                    ,    "State": {"Offset": 32, "Type": "UInt"}
                                    ,    "Protect": {"Offset": 36, "Type": "UInt"}
                                    ,    "Type": {"Offset": 40, "Type": "UInt"} }
                                :   {  "BaseAddress": {"Offset": 0, "Type": "UInt"}
                                    ,   "AllocationBase": {"Offset": 4, "Type": "UInt"}
                                    ,   "AllocationProtect": {"Offset": 8, "Type": "UInt"}
                                    ,   "RegionSize": {"Offset": 12, "Type": "UInt"}
                                    ,   "State": {"Offset": 16, "Type": "UInt"}
                                    ,   "Protect": {"Offset": 20, "Type": "UInt"}
                                    ,   "Type": {"Offset": 24, "Type": "UInt"} }

            if aLookUp.HasKey(key)
                return numget(this.pStructure+0, aLookUp[key].Offset, aLookUp[key].Type)
        }
        __set(key, value)
        {
             static aLookUp := A_PtrSize = 8
                                ?   {   "BaseAddress": {"Offset": 0, "Type": "Int64"}
                                    ,    "AllocationBase": {"Offset": 8, "Type": "Int64"}
                                    ,    "AllocationProtect": {"Offset": 16, "Type": "UInt"}
                                    ,    "RegionSize": {"Offset": 24, "Type": "Int64"}
                                    ,    "State": {"Offset": 32, "Type": "UInt"}
                                    ,    "Protect": {"Offset": 36, "Type": "UInt"}
                                    ,    "Type": {"Offset": 40, "Type": "UInt"} }
                                :   {  "BaseAddress": {"Offset": 0, "Type": "UInt"}
                                    ,   "AllocationBase": {"Offset": 4, "Type": "UInt"}
                                    ,   "AllocationProtect": {"Offset": 8, "Type": "UInt"}
                                    ,   "RegionSize": {"Offset": 12, "Type": "UInt"}
                                    ,   "State": {"Offset": 16, "Type": "UInt"}
                                    ,   "Protect": {"Offset": 20, "Type": "UInt"}
                                    ,   "Type": {"Offset": 24, "Type": "UInt"} }

            if aLookUp.HasKey(key)
            {
                NumPut(value, this.pStructure+0, aLookUp[key].Offset, aLookUp[key].Type)
                return value
            }
        }
        Ptr()
        {
            return this.pStructure
        }
        sizeOf()
        {
            return this.SizeOfStructure
        }
    }

}



;}


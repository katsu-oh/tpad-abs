#Requires AutoHotkey v2 64-bit

ListLines(False)
;-----------------------------------------------------------------------------
;@Ahk2Exe-SetFileVersion 1.0.1.0
;@Ahk2Exe-SetDescription Touchpad Utility "Touchpad`, absolutely!"
;@Ahk2Exe-SetProductName Touchpad`, absolutely!
;@Ahk2Exe-SetProductVersion 1.0.1.0
;@Ahk2Exe-SetCopyright Katsuo`, 2026
;@Ahk2Exe-SetOrigFilename TpadAbs.exe
;-----------------------------------------------------------------------------
#NoTrayIcon
#SingleInstance Force
Persistent
KeyHistory(0)
SendMode("Event")
SetMouseDelay(-1)
CoordMode("Mouse", "Screen")
Critical(5)

#DllLoad "hid"

BeforePreparsed := True
TouchPrevTickCount := A_TickCount
TouchStartTickCount := A_TickCount
ActiveContacts := False
PrevTickCount := A_TickCount
StartTickCount := A_TickCount
FirstMove := True
MoreFingers := False

Device := Buffer(8 + A_PtrSize, 0)
NumPut("UShort",0x0D, "UShort",0x05, "UInt",0x00000100, "Ptr",A_ScriptHwnd, Device)
DllCall("RegisterRawInputDevices", "Ptr",Device, "UInt",1, "UInt",8 + A_PtrSize)

OnMessage(0x00FF, OnTouch)
Exit

;-----------------------------------------------------------------------------

OnTouch(wParam, lParam, msg, hwnd) {
    ThisTickCount := A_TickCount

    Global BeforePreparsed
    Global Preparsed
    Global TouchPrevTickCount
    Global TouchStartTickCount
    Global ActiveContacts
    Global PrevTickCount
    Global StartTickCount
    Global FirstMove
    Global MoreFingers

    RawInputSize := 0
    DllCall("GetRawInputData", "Ptr",lParam, "UInt",0x10000003, "Ptr",0,        "UInt*",&RawInputSize, "UInt",8 + A_PtrSize * 2)
    RawInput := Buffer(RawInputSize, 0)
    DllCall("GetRawInputData", "Ptr",lParam, "UInt",0x10000003, "Ptr",RawInput, "UInt*",&RawInputSize, "UInt",8 + A_PtrSize * 2)

    If (BeforePreparsed) {
        hDevice := NumGet(RawInput, 8, "Ptr")
        PreparsedSize := 0
        DllCall("GetRawInputDeviceInfo", "Ptr",hDevice, "UInt",0x20000005, "Ptr",0,         "UInt*",&PreparsedSize)
        Preparsed := Buffer(PreparsedSize, 0)
        BeforePreparsed
     := DllCall("GetRawInputDeviceInfo", "Ptr",hDevice, "UInt",0x20000005, "Ptr",Preparsed, "UInt*",&PreparsedSize) <= 0
    }

    ContactCount := 0
    DllCall("hid\HidP_GetUsageValue", "Int",0x00, "UShort",0x0D, "UShort",0, "UShort",0x54, "UInt*",&ContactCount, "Ptr",Preparsed
                                    , "Ptr",RawInput.Ptr + 16 + A_PtrSize * 2, "UInt",RawInputSize - (16 + A_PtrSize * 2))

    If (TickCountDiff(ThisTickCount, TouchPrevTickCount) >= 62) {
        TouchStartTickCount := ThisTickCount
        ActiveContacts := False
    }
    If (ContactCount = 3) & (TickCountDiff(ThisTickCount, TouchStartTickCount) <= 156) {
        ActiveContacts := True
    }
    TouchPrevTickCount := ThisTickCount

    If (ActiveContacts) & (ContactCount = 3) {
        Caps := Buffer(64, 0)
        DllCall("hid\HidP_GetCaps", "Ptr",Preparsed, "Ptr",Caps)

        ValueCapsLength := NumGet(Caps, 48, "UShort")
        ValueCaps := Buffer(ValueCapsLength * 72, 0)
        DllCall("hid\HidP_GetValueCaps", "Int",0x00, "Ptr",ValueCaps, "UShort*",&ValueCapsLength, "Ptr",Preparsed)

        SumX := 0
        SumY := 0
        Offset := 0
        Loop (ValueCapsLength) {
            UsagePage := NumGet(ValueCaps, Offset + 0,  "UShort")
            Usage     := NumGet(ValueCaps, Offset + 56, "UShort")
            If (UsagePage = 0x01) {
                If (Usage = 0x30) {
                    Link := NumGet(ValueCaps, Offset + 6, "UShort")
                    X := 2 ** 30
                    DllCall("hid\HidP_GetUsageValue", "Int",0x00, "UShort",UsagePage, "UShort",Link, "UShort",Usage, "UInt*",&X, "Ptr",Preparsed
                                                    , "Ptr",RawInput.Ptr + 16 + A_PtrSize * 2, "UInt",RawInputSize - (16 + A_PtrSize * 2))
                    SumX += X
                    MaxX := NumGet(ValueCaps, Offset + 44, "Int") 
                    If (X = 2 ** 30) Or (MaxX = 0) {
                        Return
                    }
                } Else If (Usage = 0x31) {
                    Link := NumGet(ValueCaps, Offset + 6, "UShort")
                    Y := 2 ** 30
                    DllCall("hid\HidP_GetUsageValue", "Int",0x00, "UShort",UsagePage, "UShort",Link, "UShort",Usage, "UInt*",&Y, "Ptr",Preparsed
                                                    , "Ptr",RawInput.Ptr + 16 + A_PtrSize * 2, "UInt",RawInputSize - (16 + A_PtrSize * 2))
                    SumY += Y
                    MaxY := NumGet(ValueCaps, Offset + 44, "Int") 
                    If (Y = 2 ** 30) Or (MaxY = 0) {
                        Return
                    }
                }
            }
            Offset += 72
        }

        If (MoreFingers) | (TickCountDiff(ThisTickCount, PrevTickCount) >= 62) {
            StartTickCount := ThisTickCount
            FirstMove := True
            MoreFingers := False
        } Else {
            DeadzonePadLeftPercent   := 20
            DeadzonePadRightPercent  := 20
            DeadzonePadTopPercent    := 30
            DeadzonePadBottomPercent := 30

            DeadzoneDisplayLeftPixel   := 15
            DeadzoneDisplayRightPixel  := 15
            DeadzoneDisplayTopPixel    := 15
            DeadzoneDisplayBottomPixel := 15

            X := SumX / ContactCount / MaxX * 100
            Y := SumY / ContactCount / MaxY * 100
            X := (X - DeadzonePadLeftPercent) * 100 / (100 - DeadzonePadLeftPercent - DeadzonePadRightPercent )
            Y := (Y - DeadzonePadTopPercent ) * 100 / (100 - DeadzonePadTopPercent  - DeadzonePadBottomPercent)
            X := Min(Max(0 , X), 100)
            Y := Min(Max(0 , Y), 100)
            X := Round(DeadzoneDisplayLeftPixel + (A_ScreenWidth  - 1 - DeadzoneDisplayLeftPixel - DeadzoneDisplayRightPixel ) * X / 100)
            Y := Round(DeadzoneDisplayTopPixel  + (A_ScreenHeight - 1 - DeadzoneDisplayTopPixel  - DeadzoneDisplayBottomPixel) * Y / 100)

            ElapsedTickCount := TickCountDiff(ThisTickCount, StartTickCount)
            If (ElapsedTickCount >= 93) {
                If (FirstMove) {
                    FirstMove := False
                    MouseGetPos(&CurrentX, &CurrentY)
                    Dist1 := Sqrt((X - CurrentX) ** 2 + (Y - CurrentY) ** 2)
                    If (Dist1 > 0) {
                        Dist0 := Dist1 * 0.25
                        MouseMove ((Dist1 - Dist0) * X + Dist0 * CurrentX) / Dist1, ((Dist1 - Dist0) * Y + Dist0 * CurrentY) / Dist1, 0
                    }
                }
                MoveSpeed := 193 - ElapsedTickCount
                MoveSpeed := Max(0, MoveSpeed)
                MouseMove(X, Y, MoveSpeed)
            }
        }

        PrevTickCount := ThisTickCount

    } Else If (ContactCount >= 4) {
        MoreFingers := True
    }
}

;-----------------------------------------------------------------------------

TickCountDiff(After, Before) {
    If (Before - After >= 2 ** 31) {
        Return(After - Before + 2 ** 32)
    } Else {
        Return(After - Before)
    }
}

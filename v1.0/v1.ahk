#Persistent
CoordMode, Pixel, Screen
CoordMode, Mouse, Screen
CoordMode, ToolTip, Screen

; --- Estatísticas de runtime e pesca ---
runtimeS := 0
runtimeM := 0
runtimeH := 0
pescados  := 0
greenTopResets := 0 ; contador de resets de greenTop

x := Round(A_ScreenWidth / 1.859)
yStart := Round(A_ScreenHeight / 3.2)
yEnd := Round(A_ScreenHeight / 1.92)
ultimoClique := 0
greenColor := 0x64FF78
redColor := 0xFF3232
blackColor := 0x1B2A35

tolerance := 20

; Variáveis globais para controle de espera da área verde
aguardandoVerde := false
verdeTimeout := 0

scanActive := false

greenTop := ""
greenBottom := ""
barraTop := ""
barraBottom := ""
linhaY := ""

lastClickNormal := 0
lastClickFast := 0

F5::
    if (!scanActive) {
        scanActive := true
        SetTimer, ScanEClick, 25  ; timer mais rápido
        ToolTip, Script ATIVO, 10, 10, 5
        SetTimer, UpdateTooltips, 1000  ; a cada 1 segundo

    } else {
        scanActive := false
        SetTimer, ScanEClick, Off
        ToolTip
        ClickUp()  ; garante que clique está solto ao parar
    }
return

F6::
ExitApp
return

LocalizacaoSearcher:
    {
        if (greenTop != "")
        {
            localizacao := "Zona Verde: " greenTop " a " greenBottom
            localizacao .= "`nBarrinha Total: " barraTop " a " barraBottom
            localizacao .= "`nLinha Preta em Y: " linhaY
        }
        else
        {
            localizacao := "Localizacao desconhecida"
        }
    }

StatusDePesca:
    {
        if (aguardandoVerde)
        {
            status := "Aguardando area verde..."
        }
        else if (barraDetectada)
        {
            status := "Pescando..."
        }
    }

ScanEClick:
    {

        greenTop := ""
        greenBottom := ""
        barraTop := ""
        barraBottom := ""
        linhaY := ""

        ; Otimização: usar PixelSearch para encontrar rapidamente o topo e base da zona verde
        PixelSearch, , greenTop, %x%, %yStart%, %x%, %yEnd%, %greenColor%, %tolerance%, Fast RGB
        PixelSearch, , greenBottom, %x%, %yEnd%, %x%, %yStart%, %greenColor%, %tolerance%, Fast RGB

        ; Detectar limites da área vermelha (primeiro e último pixel vermelho)
        redStart := ""
        redEnd := ""
        PixelSearch, , redStart, %x%, %yStart%, %x%, %yEnd%, %redColor%, %tolerance%, Fast RGB
        PixelSearch, , redEnd, %x%, %yEnd%, %x%, %yStart%, %redColor%, %tolerance%, Fast RGB

        if (!IsSet(barraDetectada))
            barraDetectada := false

        if (redStart = "" or redEnd = "" or greenTop = "" or greenBottom = "")
        {
            ClickUp()
            now := A_TickCount

            if (barraDetectada && now - ultimoClique > 1000) {
                pescados++
                barraDetectada := false
                ultimoClique := now
                Sleep, 500
                Click down
                Sleep, 200
                Click up
                aguardandoVerde := true
                verdeTimeout := now
            } else if (!aguardandoVerde && now - ultimoClique > 1000) {
                aguardandoVerde := true
                verdeTimeout := now
                ultimoClique := now
                Click down
                Sleep, 200
                Click up
            } else if (now - verdeTimeout > 120000) {
                aguardandoVerde := false
            }
            return
        }

        if (aguardandoVerde) {
            aguardandoVerde := false
        }
        barraDetectada := true

        barraTop := greenTop - 1
        barraBottom := greenBottom + 1

        ; Detectar linha preta entre o primeiro e o último pixel vermelho
        scanRange := 10
        if (linhaY)
        {
            startY := linhaY - scanRange
            endY := linhaY + scanRange
            if (startY < redStart)
                startY := redStart
            if (endY > redEnd)
                endY := redEnd
        }
        else
        {
            startY := redStart
            endY := redEnd
        }

        linhaY := ""
        PixelSearch, , foundY, %x%, %startY%, %x%, %endY%, %blackColor%, %tolerance%, Fast RGB
        if !ErrorLevel
            linhaY := foundY

        if !linhaY
        {
            ClickUp()
            return
        }

        currentTime := A_TickCount

        ; Controle ativo para manter a linha dentro da área verde
        if (linhaY < greenTop)
        {
            ; Linha acima da área verde: solta o clique para descer
            ClickUp()
        }
        else if (linhaY > greenBottom)
        {
            ; Linha abaixo da área verde: faz vários cliques em sequência para subir
            ClickMultiple(2, 10)
            ClickUp()
        }
        else if (linhaY >= greenTop && linhaY <= greenBottom)
        {
            ; Só ativa o clique se a linha estiver na metade de baixo da área verde
            metadeVerde := greenTop + ((greenBottom - greenTop) // 2)
            if (linhaY >= metadeVerde) {
                ; Linha na metade de baixo da área verde: faz clique(s) para manter
                ClickMultiple(1, 400)
            }
            ClickUp()
        }
        else
        {
            ClickUp()
        }
        return
    }

    ClickMultiple(qtd, delay)
    {
        Loop, %qtd%
        {
            Click
            Sleep, %delay%
        }
    }
    ClickDown()
    {
        static clicked := false
        if !clicked
        {
            Click down
            clicked := true
        }
    }

    ClickUp()
    {
        static clicked := false
        if clicked
        {
            Click up
            clicked := false
        }
    }

    ColorDiff(c1, c2)
    {
        r1 := (c1 >> 16) & 0xFF
        g1 := (c1 >> 8) & 0xFF
        b1 := c1 & 0xFF
        r2 := (c2 >> 16) & 0xFF
        g2 := (c2 >> 8) & 0xFF
        b2 := c2 & 0xFF
        return Abs(r1 - r2) + Abs(g1 - g2) + Abs(b1 - b2)
    }

; -----------------------------------------------------
; Timer para atualizar as três tooltips
UpdateTooltips:
    {
        runtimeS++
        if (runtimeS >= 60) {
            runtimeS := 0
            runtimeM++
        }
        if (runtimeM >= 60) {
            runtimeM := 0
            runtimeH++
        }
        Gosub, LocalizacaoSearcher
        ; imprime três tooltips estáticas, cada uma com seu ID
        ToolTip, Tempo jogado: %runtimeH%h %runtimeM%m %runtimeS%s, 20, 50, 1
        ToolTip, Pescados: %pescados%,               20, 80, 2
        ToolTip, Status: %status%,                  20, 110, 3
        Tooltip, Localizacao: %localizacao%, 20, 140, 4
        return
    }

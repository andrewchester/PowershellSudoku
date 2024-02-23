Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

######### Game Variables ##########

# Undo Stack Variables
$script:stack = @()
$script:stackcount = 0
$script:stacklim = 10

# Counts for each number
$script:counts = @(0)*9

# Puzzle source
$source = Get-Content -Path "$pwd/puzzles10k.txt"
$npuzzles = $source.Count / 9
$script:puzzle = -1

# State variables
$script:won = 0
$script:hints = 3
$script:successes = 0
$script:failures = 0
$script:winrate = 0

# Toggles
$script:highlighting = 0
$script:movemode = $false
$script:movelayer = 0
$script:jumpmode = $false
$script:helpmenutoggle = $false
$script:zentoggle = $false

# Board info
$CELLSIZE = 40
$rows = 9
$cols = 9
$xoff = 120
$yoff = 100
$cells = @(0)*$rows
for ($i = 0; $i -ne $rows; $i++) {
    $cells[$i] = @(0)*$cols
}
$selected = @(4,4)

########## Window Object ##########

$win = new-object System.Windows.Forms.Form
$win.FormBorderStyle = 'FixedDialog'
$win.Text = "Sudoku"
$win.Width = 600
$win.Height = 600
$win.BackColor = "#ffffff"
$wingraphics = $win.createGraphics()

########## Timer Object ##########
$script:time = 0
$script:besttime = 99999999
$script:worsttime = -1
$script:averagetime = 0
$script:timer = new-object System.Windows.Forms.Timer
$script:timer.Interval = 1000
$script:timer.Enabled = $false
$script:timer.Add_Tick({
    if ($script:time -lt 999) {
        $script:time++
    }
    
    if (-not $script:zentoggle) {
        & draw_time
    }
})

########## Networking Variables ##########
$NETWORKING = $true
<#
# 0 waiting for connection
# 1 connected and playing
$NETSTATE = 0
 
$CLIENTPORT = 20203
$clientend = New-Object System.Net.IPEndPoint ([IPAddress]::Any, $CLIENTPORT)
while($true) {
    $socket = New-Object System.Net.Sockets.UdpClient $CLIENTPORT
    $content = $socket.Receive([ref]$clientend)
    $socket.Close()
    [Text.Encoding]::ASCII.GetString($content)
}
 
 
$PEERPORT = 20202
$IP = "127.0.0.1"
$peeraddr = [System.Net.IPAddress]::Parse($IP)
$peerend = new-object System.Net.IPEndPoint $peeradr, $PEERPORT

$Saddrf   = [System.Net.Sockets.AddressFamily]::InterNetwork 
$Stype    = [System.Net.Sockets.SocketType]::Dgram 
$Ptype    = [System.Net.Sockets.ProtocolType]::UDP 
$Sock     = New-Object System.Net.Sockets.Socket $saddrf, $stype, $ptype 
$Sock.TTL = 26 

$CLIENTPORT = 20203
$clientend = New-Object System.Net.IPEndPoint ([IPAddress]::Any, $CLIENTPORT)
while($true) {
    $socket = New-Object System.Net.Sockets.UdpClient $CLIENTPORT
    $content = $socket.Receive([ref]$clientend)
    $socket.Close()
    [Text.Encoding]::ASCII.GetString($content)
}#>


########## Brush Objects ##########

$linepen = new-object Drawing.pen "#000000"
$cellforeground = new-object Drawing.SolidBrush "#ffffff"
$cellbackground = new-object Drawing.SolidBrush "#aaa1a1"
$cellselected = new-object Drawing.SolidBrush "#f1f1f1"
$cellselected_highlighting = new-object Drawing.SolidBrush "#e6e6e6"
$victory = new-object Drawing.SolidBrush "#66ff66"
$besttimebrush = new-object Drawing.SolidBrush "#00e600"
$complete = new-object Drawing.SolidBrush "#00cc00"
$failure = new-object Drawing.SolidBrush "#ff4d4d"
$transparentbackground = [Drawing.SolidBrush]::New([Drawing.Color]::FromArgb(100, 204, 204, 204))

$numbrush = new-object Drawing.SolidBrush "#000000"
$numbrushwritten = new-object Drawing.SolidBrush "#666666"
$font = new-object System.Drawing.Font Consolas,24 
$buttonfont = new-object System.Drawing.Font Consolas,11
$statsfont = new-object System.Drawing.Font Consolas,9
$titlefont = new-object System.Drawing.Font Consolas,30

########## Drawing Functions ##########

function highlight_nums {
    param (
        $n, $state
    )

    if ($selected[1] -lt 0 -or $selected[1] -gt 8) {
        return
    }

    if ($n -eq 0 -or $n -eq 10) {
        return
    }

    for ($x = 0; $x -ne 9; $x++) {
        for ($y = 0; $y -ne 9; $y++) {
            if ($cells[$x][$y] -eq 0 -or $cells[$x][$y] -eq 10) {
                continue
            }
            
            if (($cells[$x][$y]%10) -eq ($n%10)) {
                & draw_cell $x $y $cells[$x][$y] $state
            }
        }
    }
    if ($state -eq 1) {
        & draw_cell $selected[0] $selected[1] $cells[$selected[0]][$selected[1]] 3
    }
}

function highlight_coverage {
    param (
        $x, $y, $state
    )

    if ($selected[1] -lt 0 -or $selected[1] -gt 8) {
        return
    }

    $sq = ([Math]::Floor($y/3)*3) + [Math]::Floor($x/3)

    for ($i = 0; $i -ne 9; $i++) {
        & draw_cell $i $y $cells[$i][$y] $state
        & draw_cell $x $i $cells[$x][$i] $state
    }

    $x = ($sq % 3)*3
    $y = [Math]::Floor($sq/3)*3

    for ($i = $x; $i -ne $x+3; $i++) {
        for ($j = $y; $j -ne $y+3; $j++) {
            & draw_cell $i $j $cells[$i][$j] $state
        }
    }

    if ($state -eq 1) {
        & draw_cell $selected[0] $selected[1] $cells[$selected[0]][$selected[1]] 3
    }
}

function apply_highlighting {
    param (
        $state
    )

    & draw_cell $selected[0] $selected[1] $cells[$selected[0]][$selected[1]] $state
    if ($script:highlighting -eq 1) {
        & highlight_nums $cells[$selected[0]][$selected[1]] $state
    } elseif ($script:highlighting -eq 2) {
        & highlight_coverage $selected[0] $selected[1] $state
    }
    & draw_grid
}

function draw_move_mode {
    $wingraphics.FillRectangle($cellforeground, 440, 530, 200, 50)
    $wingraphics.FillRectangle($cellforeground, 10, 10, 150, 30)

    if ($script:movelayer -eq 0) {
        $wingraphics.DrawString("Placing", $buttonfont, $numbrush, 10, 10)
    } elseif ($script:movelayer -eq 1) {
        $wingraphics.DrawString("Selecting Square", $buttonfont, $numbrush, 10, 10)
    } elseif ($script:movelayer -eq 2) {
        $wingraphics.DrawString("Selecting Cell", $buttonfont, $numbrush, 10, 10)
    }

    if ($script:movemode -eq $true) {
        $wingraphics.DrawString("Move Mode ON", $buttonfont, $numbrush, 440, 530)
    } else {
        $wingraphics.DrawString("Move Mode OFF", $buttonfont, $numbrush, 440, 530)
    }
}

function draw_jump_mode {
    $wingraphics.FillRectangle($cellforeground, 10, 530, 140, 25)
    if ($script:jumpmode) {
        $wingraphics.DrawString("Jump Mode ON", $buttonfont, $numbrush, 10, 530)
    } else {
        $wingraphics.DrawString("Jump Mode OFF", $buttonfont, $numbrush, 10, 530)
    }
}

function draw_help_menu {
    $wingraphics.FillRectangle($transparentbackground,0,0,600,600)
    $wingraphics.FillRectangle($cellforeground, 195, 50, 210, 400)

    $wingraphics.DrawRectangle($linepen, 195, 50, 210, 400)

    $wingraphics.DrawString("Help Menu", $buttonfont, $numbrush, 260, 60)
    $wingraphics.DrawLine($linepen, 245, 77, 355, 77)

    $wingraphics.DrawString("Toggle Move Mode with Shift", $statsfont, $numbrushwritten, 210, 90)
    $wingraphics.DrawString("With move mode, use the", $statsfont, $numbrushwritten, 210, 120)
    $wingraphics.DrawString("numpad to pick a 3x3 box,", $statsfont, $numbrushwritten, 210, 140)
    $wingraphics.DrawString("then pick a cell and place", $statsfont, $numbrushwritten, 210, 160)
    $wingraphics.DrawString("a number", $statsfont, $numbrushwritten, 210, 180)

    $wingraphics.DrawString("Toggle Jump Mode with Tab", $statsfont, $numbrushwritten, 210, 250)
    $wingraphics.DrawString("In Jump Mode, arrow keys", $statsfont, $numbrushwritten, 210, 280)
    $wingraphics.DrawString("jump between 3x3 boxes", $statsfont, $numbrushwritten, 210, 300)
    $wingraphics.DrawString("instead of cells", $statsfont, $numbrushwritten, 210, 320)

    $wingraphics.DrawString("press h to get a hint", $statsfont, $numbrushwritten, 210, 360)
    $wingraphics.DrawString("press n for a new puzzle", $statsfont, $numbrushwritten, 210, 380)
}

function draw_time {
    $digits = 1
    $temp = $script:time
    while ($temp -ge 10) {
        $temp /= 10
        $digits++
    } 

    $wingraphics.FillRectangle($cellforeground, $xoff+(3*$CELLSIZE), 500, 3*$CELLSIZE, 70)
    $wingraphics.DrawString($script:time.ToString(), $titlefont, $numbrush, 285-(8*$digits), 500)
}

function draw_stats {
    $wingraphics.FillRectangle($cellforeground, 0,$yoff, $xoff-5, 9*$CELLSIZE)
    

    $wingraphics.DrawString("Best Time", $statsfont, $numbrush, 10, $yoff)
    if ($script:besttime -le 999) {
        $wingraphics.DrawString($script:besttime.ToString(), $statsfont, $victory, 10, $yoff+25)
    }
    $wingraphics.DrawString("Worst Time", $statsfont, $numbrush, 10, $yoff + 50)
    if ($script:worsttime -gt -1) {
        $wingraphics.DrawString($script:worsttime.ToString(), $statsfont, $failure, 10, $yoff+75)
    }
    $wingraphics.DrawString("Average", $statsfont, $numbrush, 10, $yoff + 100)
    if ($script:averagetime -ne 0) {
        $wingraphics.DrawString($script:averagetime.ToString(), $statsfont, $numbrush, 10, $yoff+125)
    }

    $wingraphics.DrawString("Won: ", $statsfont, $numbrush, 10, $yoff + 175)
    $wingraphics.DrawString($script:successes.ToString(), $statsfont, $numbrush, 10, $yoff+200)
    
    $wingraphics.DrawString("Lost: ", $statsfont, $numbrush, 10, $yoff + 225)
    $wingraphics.DrawString($script:failures.ToString(), $statsfont, $numbrush, 10, $yoff+250)

    $wingraphics.DrawString("Win Rate: ", $statsfont, $numbrush, 10, $yoff + 275)
    $wingraphics.DrawString($script:winrate.ToString()+" %", $statsfont, $numbrush, 10, $yoff+300)
}

function draw_buttons {
    $wingraphics.FillRectangle($cellforeground, $xoff, 60, 9*$CELLSIZE, 30)
    $wingraphics.FillRectangle($cellforeground, $xoff, $yoff+($CELLSIZE*9)+10, 9*$CELLSIZE, 30)

    if ($selected[1] -eq -1 -and ($selected[0] % 3) -eq 0) {
        $wingraphics.FillRectangle($cellselected, $xoff, 60, 100, 25)    
    }
    $wingraphics.DrawRectangle($linepen, $xoff, 60, 100, 25)
    $wingraphics.DrawString("New Puzzle", $buttonfont, $numbrush, $xoff+5, 64)

    if ($selected[1] -eq -1 -and ($selected[0] % 3) -eq 1) {
        if ($script:won -eq 2) {
            $wingraphics.FillRectangle($victory, $xoff+120, 60, 115, 25)
        } elseif ($script:won -eq 1) {
            $wingraphics.FillRectangle($failure, $xoff+120, 60, 115, 25)
        } else {
            $wingraphics.FillRectangle($cellselected, $xoff+120, 60, 115, 25)
        }
    }
    $wingraphics.DrawRectangle($linepen, $xoff+120, 60, 115, 25)
    $wingraphics.DrawString("Check Answer", $buttonfont, $numbrush, $xoff+125, 64)

    if ($selected[1] -eq -1 -and $selected[0] % 3 -eq 2) {
        $wingraphics.FillRectangle($cellselected, $xoff+260, 60, 55, 25)
    }
    $wingraphics.DrawRectangle($linepen, $xoff+260, 60, 55, 25)
    $wingraphics.DrawString("Clear", $buttonfont, $numbrush, $xoff+265, 64)

    if ($selected[1] -eq 9 -and $selected[0] % 3 -eq 0) {
        $wingraphics.FillRectangle($cellselected, $xoff, $yoff+($CELLSIZE*9)+10, 85, 25)
    }
    $wingraphics.DrawRectangle($linepen, $xoff, $yoff+($CELLSIZE*9)+10, 85,25)
    $wingraphics.DrawString("Hint ($script:hints)", $buttonfont, $numbrush, $xoff+7, $yoff+($CELLSIZE*9)+14)

    if($selected[1] -eq 9 -and $selected[0] % 3 -eq 1) {
        $wingraphics.FillRectangle($cellselected, $xoff+($CELLSIZE*2)+15, $yoff+($CELLSIZE*9)+10, 200,25)
    }

    $wingraphics.DrawRectangle($linepen, $xoff+($CELLSIZE*2)+15, $yoff+($CELLSIZE*9)+10, 200,25)
    if ($script:highlighting -eq 1) {
        $wingraphics.DrawString("Highlighting: numbers ", $buttonfont, $numbrush, $xoff+($CELLSIZE*2)+22, $yoff+($CELLSIZE*9)+14)
    } elseif ($script:highlighting -eq 2) {
        $wingraphics.DrawString("Highlighting: coverage", $buttonfont, $numbrush, $xoff+($CELLSIZE*2)+22, $yoff+($CELLSIZE*9)+14)
    } else {
        $wingraphics.DrawString("Highlighting: off     ", $buttonfont, $numbrush, $xoff+($CELLSIZE*2)+42, $yoff+($CELLSIZE*9)+14)
    }

    if ($selected[1] -eq 9 -and $selected[0] % 3 -eq 2) {
        $wingraphics.FillRectangle($cellselected, $xoff+($CELLSIZE*7)+25, $yoff+($CELLSIZE*9)+10, $CELLSIZE, 25)
    }
    
    $wingraphics.DrawRectangle($linepen, $xoff+($CELLSIZE*7)+25, $yoff+($CELLSIZE*9)+10, $CELLSIZE, 25)
    $wingraphics.DrawString("Zen", $buttonfont, $numbrush, $xoff+($CELLSIZE*7)+30, $yoff+($CELLSIZE*9)+14)
}

function draw_grid {
    $wingraphics.DrawRectangle($linepen, $xoff, $yoff, 9*$CELLSIZE, 9*$CELLSIZE)
    $wingraphics.DrawRectangle($linepen, $xoff-1, $yoff-1, 9*$CELLSIZE+2, 9*$CELLSIZE+2)

    for ($i = 1; $i -ne 3; $i++) {
        $wingraphics.DrawLine($linepen, $xoff, $yoff+($i*120), $xoff+360, $yoff+($i*120))
        $wingraphics.DrawLine($linepen, $xoff+($i*120), $yoff, $xoff+($i*120), $yoff+360)
    }
}

function draw_num_counts {
    $xpos = $xoff + (9*$CELLSIZE) + 20

    $wingraphics.FillRectangle($cellforeground, $xoff+(9*$CELLSIZE)+15, $yoff, 50, 9*$CELLSIZE)

    for ($y = 0; $y -ne 9; $y++) {
        if ($counts[$y] -ge 9) {
            $wingraphics.DrawString(($y+1).ToString(), $font, $complete, $xpos, $yoff+($y*$CELLSIZE)+1)
        }
    }
}

function draw_cell {
    param (
        $x, $y, $n, $selected
    )

    if ($x -lt 0 -or $x -ge 9 -or $y -lt 0 -or $y -ge 9) {
        return
    }

    $xpos = ($x*$CELLSIZE) + $xoff
    $ypos = ($y*$CELLSIZE) + $yoff

    $wingraphics.FillRectangle($cellbackground, $xpos, $ypos, $CELLSIZE, $CELLSIZE)

    if ($selected -eq 1) {
        $wingraphics.FillRectangle($cellselected, $xpos+1, $ypos+1, $CELLSIZE-2, $CELLSIZE-2)
    } elseif ($selected -eq 2) {
        $wingraphics.FillRectangle($failure, $xpos+1, $ypos+1, $CELLSIZE-2, $CELLSIZE-2)
    } elseif ($selected -eq 3) {
        $wingraphics.FillRectangle($cellselected_highlighting, $xpos+1, $ypos+1, $CELLSIZE-2, $CELLSIZE-2)
    } else {
        $wingraphics.FillRectangle($cellforeground, $xpos+1, $ypos+1, $CELLSIZE-2, $CELLSIZE-2)
    }

    if ($n -ge 1 -and $n -le 9) {
        $wingraphics.DrawString($n.ToString(), $font, $numbrushwritten, $xpos+4.5,$ypos+.5)
    }
    
    if ($n -ge 11 -and $n -le 19) {
        $wingraphics.DrawString(($n-10).ToString(), $font, $numbrush, $xpos+4.5, $ypos+.5)
    }
}

function draw_puzzle {
    if ($script:highlighting -eq 1 -and $cells[$selected[0]][$selected[1]] -ne 10 -and $cells[$selected[0]][$selected[1]] -ne 0) {
        & highlight_nums $cells[$selected[0]][$selected[1]] 0
    } elseif ($script:highlighting -eq 2) {
        & highlight_coverage $selected[0] $selected[1] 0
    } else {
        & draw_cell $selected[0] $selected[1] $cells[$selected[0]][$selected[1]] 0
    }
    
    $wingraphics.FillRectangle($cellforeground, $xoff, $yoff, 9*$CELLSIZE, 9*$CELLSIZE)
    for ($x = 0; $x -ne $rows; $x++) {
        for ($y = 0; $y -ne $cols; $y++) {
            & draw_cell $x $y $cells[$x][$y] 0
        }
    }

    if ($script:highlighting -eq 1 -and $cells[$selected[0]][$selected[1]] -ne 10 -and $cells[$selected[0]][$selected[1]] -ne 0) {
        & highlight_nums $cells[$selected[0]][$selected[1]] 1
    } elseif ($script:highlighting -eq 2) {
        & highlight_coverage $selected[0] $selected[1] 1
    } else {
        & draw_cell $selected[0] $selected[1] $cells[$selected[0]][$selected[1]] 1
    }

    & draw_grid
}

function draw_extra_info {
    & draw_buttons

    $wingraphics.DrawString("Sudoku", $titlefont, $numbrush, $xoff+105, 10)
    
    & draw_stats
    & draw_time
    & draw_num_counts
    & draw_move_mode
    & draw_jump_mode
}

########## Game Functions ##########

function update_cell_value {
    param (
        $x,
        $y,
        $value
    )

    $currentval = $cells[$x][$y]

    # bounds check value placed
    if ($value -ge 0 -and $value -lt 10 -and $currentval -le 10) {
        $currentval %= 10

        if ($script:puzzle -ne -1) {
            $script:timer.Enabled = $true
        }

        # update counts of each number
        if ($currentval -ne 0 -and $currentval -ne 10) {
            $script:counts[$currentval-1]--
        }
        if ($value -ne 0) {
            $script:counts[$value-1]++
        }

        # add value to undo stack
        if ($script:stackcount -eq 10) {
            $script:stack = $script:stack[0..($script:stack.Count-2)]
        } else {
            $script:stackcount++
        }
        $script:stack += $x, $y, $currentval

        $cells[$x][$y] = $value

        & draw_cell $x $y $value 1
        & draw_grid
        & draw_num_counts
    }   
}

function give_hint {
    for ($row = 0; $row -ne 9; $row++) {
        $zeroidx = -1
        $zeros = 0
        $nums = @(0)*9

        for ($col = 0; $col -ne 9; $col++) {
            if ($cells[$row][$col] -eq 10 -or $cells[$row][$col] -eq 0) {
                $zeros++
                $zeroidx = $col
            } else {
                $nums[($cells[$row][$col]%10)-1] = 1
            }
        }

        if ($zeros -eq 1) {
            $n = 0
            for ($i = 0; $i -ne 9; $i++) {
                if ($nums[$i] -eq 0) {
                    $n = $i+1
                    break
                }
            }
            & update_cell_value $row $zeroidx $n
            $script:hints--
            return
        }
    }

    for ($col = 0; $col -ne 9; $col++) {
        $zeroidx = -1
        $zeros = 0
        $nums = @(0)*9

        for ($row = 0; $row -ne 9; $row++) {
            if ($cells[$row][$col] -eq 10 -or $cells[$row][$col] -eq 0) {
                $zeros++
                $zeroidx = $row
            } else {
                $nums[($cells[$row][$col]%10)-1] = 1
            }
        }

        if ($zeros -eq 1) {
            $n = 0
            for ($i = 0; $i -ne 9; $i++) {
                if ($nums[$i] -eq 0) {
                    $n = $i+1
                    break
                }
            }
            & update_cell_value $zeroidx $col $n
            $script:hints--
            return
        }
    }
    
    for ($sq = 0; $sq -ne 9; $sq++) {
        $x = ($sq % 3)*3
        $y = [Math]::Floor($sq / 3)*3
        
        $zeroidx = -1
        $zeros = 0
        $nums = @(0)*9

        for ($i = $x; $i -ne $x+3; $i++) {
            for ($j = $y; $j -ne $y+3; $j++) {
                if ($cells[$i][$j] -eq 10 -or $cells[$i][$j] -eq 0) {
                    $zeroidx = $i, $j
                    $zeros++
                } else {
                    $nums[($cells[$i][$j]%10)-1] = 1
                }
            }
        }

        if ($zeros -eq 1) {
            $n = 0
            for ($i = 0; $i -ne 9; $i++) {
                if ($nums[$i] -eq 0) {
                    $n = $i+1
                    break
                }
            }
            & update_cell_value $zeroidx[0] $zeroidx[1] $n
            $script:hints--
            return
        }
    }
}

function load_puzzle {
    param (
        $regen
    )
    
    if ($regen -eq 1) {
        $script:puzzle = (Get-Random -Minimum 0 -Maximum $npuzzles)*9
    }

    $script:counts = @(0)*9

    for ($i = 0; $i -ne 9; $i++) {
       for ($c = 0; $c -ne 9; $c++) {
            $n = [Convert]::ToInt32($source[$puzzle+$i][$c],10)

            if ($n -ne 0) {
                $script:counts[$n-1]++
            }

            $cells[$i][$c] = $n + 10
       }
    }

    $script:timer.Enabled = $false
    $script:time = 0

    & draw_puzzle
    & draw_num_counts
}

function check_answer {
    $rows = @(0)*9
    $cols = @(0)*9
    $sqs  = @(0)*9

    for ($i = 0; $i -ne 9; $i++) {
        $rows[$i] = @(0)*9
        $cols[$i] = @(0)*9
        $sqs[$i] = @(0)*9
    }


    for ($x = 0; $x -ne 9; $x++) {
        for ($y = 0; $y -ne 9; $y++) {
            $n = $cells[$x][$y] % 10

            if ($n -eq 0) {
                & draw_cell $x $y $n 2
                return
            }

            $n -= 1
            $sq = [Math]::Floor($x/3)+([Math]::Floor($y/3)*3)

            if ($cols[$x][$n] -eq 1 -or $rows[$y][$n] -eq 1 -or $sqs[$sq][$n] -eq 1) {
                & draw_cell $x $y ($n+1) 2
                return $false
            }

            $cols[$x][$n] = 1
            $rows[$y][$n] = 1
            $sqs[$sq][$n] = 1
        }
    }

    return $true
}

function clear_puzzle {
    if ($script:puzzle -eq -1) {
        for ($x = 0; $x -ne 9; $x++) {
            for ($y = 0; $y -ne 9; $y++) {
                $cells[$x][$y] = 0
                & draw_cell $x $y 0 0
            }
        }
        & draw_grid
        return
    }
    
    & load_puzzle 0
    $script:won = 0
    $stack = @()
}

########## Window Events ##########

$win.add_paint({
    & draw_puzzle
    & draw_buttons

    $wingraphics.DrawString("Sudoku", $titlefont, $numbrush, $xoff+105, 10)
    
    & draw_stats
    & draw_time
    & draw_num_counts
    & draw_move_mode
    & draw_jump_mode
})

$win.Add_KeyDown({
    $key = $PSItem.KeyCode.ToString()
    $numpads = "NumPad7", "NumPad8", "NumPad9", "NumPad4", "NumPad5", "NumPad6", "NumPad1", "NumPad2", "NumPad3"
    $numpadsidx = "NumPad1", "NumPad2", "NumPad3", "NumPad4", "NumPad5", "NumPad6", "NumPad7", "NumPad8", "NumPad9" 
    $numkeys = "D1", "D2", "D3", "D4", "D5", "D6", "D7", "D8", "D9" 

    if ($key -eq "r" -or $key -eq "R") {
        $win.Width = 800
    }

    if ($key -eq "Escape") {
        $script:helpmenutoggle = -not $script:helpmenutoggle
    
        if ($script:helpmenutoggle) {
            $script:timer.Enabled = $false
            & draw_help_menu
        } else {
            $win.Refresh()
            if ($script:puzzle -ne -1) { 
                $script:timer.Enabled = $true
            }
        }

        return
    }

    if ($script:helpmenutoggle) {
      return
    }

    if ($key -eq "Tab") {
        $script:jumpmode = -not $script:jumpmode
        & draw_jump_mode
    }

    if ($key -eq "ShiftKey" -or ("Right", "d", "Left", "a", "Up", "w", "Down", "s" -contains $key -and $script:movemode)) {
        $script:movemode = -not $script:movemode
        $script:movelayer = 0
        
        if ($script:movemode) {
            $script:movelayer = 1
        }
        
        & draw_move_mode
    }

    if ($key -eq "Return" -and $selected[0] -ge 0 -and $selected[0] -le 8 -and $selected[1] -ge 0 -and $selected[1] -le 8) {
        if ($script:zentoggle) {
            $selected[0] = 4
            $selected[1] = 4

            $result = & check_answer

            if ($result -eq $true) {
                $script:won = 2
                $script:timer.Enabled = $false
                $script:successes++
                
                if ($script:besttime -gt $script:time) {
                    $script:besttime = $script:time
                }
                if ($script:worsttime -lt $script:time) {
                    $script:worsttime = $script:time
                }
            
                $script:averagetime = [Math]::Floor((($script:averagetime*($script:successes+$script:failures-1))+$script:time)/($script:successes+$script:failures))
                $script:time = 0
                
                & load_puzzle 1
            } else {
                $script:failures++
                $script:won = 1
            }

            $script:winrate = [Math]::Floor(100*($script:successes/($script:failures+$script:successes)))

            $script:movemode = -not $script:movemode
            $script:movelayer = 0
            
            if ($script:movemode) {
                $script:movelayer = 1
            }

            return
        }
        
        if ($script:highlighting -eq 1) {
            & highlight_nums $cells[$selected[0]][$selected[1]] 0
        } else {
            & draw_cell $selected[0] $selected[1] $cells[$selected[0]][$selected[1]] 0
        }

        $selected[0] = 1
        $selected[1] = -1
    }

    if (($key -eq "Return" -and $selected[1] -eq -1 -and ($selected[0] % 3) -eq 0) -or ($key -eq "N" -and $selected[1] -ge 0 -and $selected[1] -le 8)) {
        $script:won = 0
        $script:hints = 3
        $selected[0] = 4
        $selected[1] = 4
        $script:stack = @()
        $script:stackcount = 0
        & load_puzzle 1
        $win.Refresh()
    }

    if ($key -eq "Return" -and $selected[1] -eq -1 -and ($selected[0] % 3) -eq 1 -and $script:puzzle -ne -1) {
        $result = & check_answer

        if ($result -eq $true) {
            $script:won = 2
            $script:timer.Enabled = $false
            $script:successes++
            
            if ($script:besttime -gt $script:time) {
                $script:besttime = $script:time
            }
            if ($script:worsttime -lt $script:time) {
                $script:worsttime = $script:time
            }
        
            $script:averagetime = [Math]::Floor((($script:averagetime*($script:successes+$script:failures-1))+$script:time)/($script:successes+$script:failures))
            $script:time = 0
            $script:puzzle = -1
        } else {
            $script:failures++
            $script:won = 1
        }

        $script:winrate = [Math]::Floor(100*($script:successes/($script:failures+$script:successes)))

        $script:movemode = -not $script:movemode
        $script:movelayer = 0
        
        if ($script:movemode) {
            $script:movelayer = 1
        }
        
        & draw_move_mode

        #& draw_time
        & draw_stats
        & draw_buttons
    }

    if ($key -eq "Return" -and $selected[1] -eq -1 -and ($selected[0] % 3) -eq 2) {
        $script:hints = 3
        & clear_puzzle
        & draw_time
        & draw_stats
    }

    if ((($key -eq "Return" -and $selected[1] -eq 9 -and $selected[0] % 3 -eq 0) -or ($key -eq "H" -and $selected[1] -ge 0 -and $selected[1] -le 8)) -and $script:hints -gt 0) {
        & give_hint
        & draw_buttons
        & draw_puzzle
    }

    if ($key -eq "Return" -and $selected[1] -eq 9 -and $selected[0]%3 -eq 1) {
        if ($script:highlighting -eq 2) {
            $script:highlighting = 0
        } else {
            $script:highlighting++
        }
        & draw_buttons
    }

    if (($key -eq "Return" -and $selected[1] -eq 9 -and $selected[0]%3 -eq 2) -or $key -eq "z") {
        $selected[0] = 4
        $selected[1] = 4
        $script:zentoggle = $true
        
        $wingraphics.FillRectangle($cellforeground, 0,0,600,600)
        
        if ($script:puzzle -eq -1) {
            & load_puzzle 1
        } else {
            & draw_puzzle
        }
        return
    }

    if ($key -eq "Space" -or $key -eq "NumPad0" -or $key -eq "D0") {
        if ($script:movemode -and $script:movelayer -ne 0) {
            return
        }
        
        if ($cells[$selected[0]][$selected[1]]%10 -eq 0 -or $cells[$selected[0]][$selected[1]] -ge 10) {
            return
        }

        & apply_highlighting 0

        & update_cell_value $selected[0] $selected[1] 0

        & apply_highlighting 1
    }

    if (($numkeys -contains $key -or ($script:movemode -eq $false -and $numpadsidx -contains $key)) -and $selected[1] -ge 0 -and $selected[1] -le 8) {
        & apply_highlighting 0
        $num = 0
        if ($numkeys -contains $key) {
            $num = [Array]::indexof($numkeys, $key) + 1
        } elseif($numpadsidx -contains $key) {
            $num = [Array]::indexof($numpadsidx, $key) + 1
        }

        & update_cell_value $selected[0] $selected[1] $num
        & apply_highlighting 1
    }

    if ($script:movemode -eq $true -and $numpads -contains $key) {
        & apply_highlighting 0
        $num = [Array]::indexof($numpads, $key)
        
        if ($script:movelayer -eq 1) {
            $selected[0] = ($num%3)*3+1
            $selected[1] = ([Math]::Floor($num/3)*3)+1

            $script:movelayer = 2
        } elseif ($script:movelayer -eq 2) {
            if ($num%3 -eq 0) {
                $selected[0] -= 1
            } elseif ($num%3 -eq 2) {
                $selected[0] += 1
            }

            $num = [Math]::Floor($num/3)
            if ($num -eq 0) {
                $selected[1] -= 1
            } elseif ($num -eq 2) {
                $selected[1] += 1
            }

            $script:movelayer = 0
        } elseif ($script:movelayer -eq 0) {
            $num = [Array]::indexof($numpadsidx, $key)+1

            & update_cell_value $selected[0] $selected[1] $num

            $script:movelayer = 1
        }

        & apply_highlighting 1
        & draw_move_mode
    }

    if ($key -eq "U" -and $stackcount -ne 0) {
        & apply_highlighting 0
        
        if ($script:stack[-1] -ne 0) {
            $script:counts[$script:stack[-1]-1]++
        }
        if ($cells[$script:stack[-3]][$script:stack[-2]] -ne 0 -and $cells[$script:stack[-3]][$script:stack[-2]] -ne 10) {
            $script:counts[$cells[$script:stack[-3]][$script:stack[-2]]-1]--
        }
        
        $cells[$script:stack[-3]][$script:stack[-2]] = $script:stack[-1]
        & draw_cell $script:stack[-3] $script:stack[-2] $script:stack[-1] 0

        if ($script:stackcount -eq 1) {
            $script:stack = @()
        } else {
            $script:stack = $script:stack[0..($script:stack.Count-4)]
        }

        $script:stackcount--
        & apply_highlighting 1
    }

    if ($key -in "Right", "Left", "Up", "Down", "w", "s", "a", "d") {
        if ($script:movemode) {
            $script:movemode = $false
            $script:movelayer = 1
        }
        
        & apply_highlighting 0
        $sq = [Math]::Floor($selected[0]/3)+([Math]::Floor($selected[1]/3)*3)

        if ($key -eq "Right" -or $key -eq "d") {
            if ($script:jumpmode) {
                if ($sq%3 -eq 2) {
                    $sq -= 2
                } else {
                    $sq++
                }

                $selected[0] = ($sq%3)*3+1
                $selected[1] = [Math]::Floor($sq/3)*3+1
            } else {
                if ($selected[0] -eq 8) {
                    $selected[0] = 0
                } else {
                    $selected[0]++
                }
            }
        } elseif ($key -eq "Left" -or $key -eq "a") {
            if ($script:jumpmode) {
                    if ($sq%3 -eq 0) {
                        $sq += 2
                    } else {
                        $sq--
                    }

                    $selected[0] = ($sq%3)*3+1
                    $selected[1] = [Math]::Floor($sq/3)*3+1
            } else {
                if ($selected[0] -eq 0) {
                    $selected[0] = 8
                } else {
                    $selected[0]--
                }
            }
        } elseif($key -eq "Up" -or $key -eq "w") {
            if ($script:jumpmode) {
                if ([Math]::Floor($sq/3) -eq 0) {
                    $sq += 6
                } else {
                    $sq -= 3
                }

                $selected[0] = ($sq%3)*3+1
                $selected[1] = [Math]::Floor($sq/3)*3+1
            } else {
                if ($selected[1] -eq -1) {
                    $selected[1] = 9
                } else {
                    $selected[1]--

                    if ($selected[1] -eq -1) {
                        $selected[0] = $sq%3
                    } elseif ($selected[1] -eq 8) {
                        $selected[0] = ($selected[0]%3)*3+1
                        & draw_buttons
                    }
                }
            }
        } elseif ($key -eq "Down" -or $key -eq "s") {
            if ($script:jumpmode) {
                if ([Math]::Floor($sq/3) -eq 2) {
                    $sq -= 6
                } else {
                    $sq += 3
                }

                $selected[0] = ($sq%3)*3+1
                $selected[1] = [Math]::Floor($sq/3)*3+1
            } else {
                if ($selected[1] -eq 9) {
                    $selected[1] = -1
                } else {
                    $selected[1]++
                    
                    if ($selected[1] -eq 9) {
                        $selected[0] = $sq%3
                    } elseif($selected[1] -eq 0) {
                        $selected[0] = ($selected[0]%3)*3+1
                        & draw_buttons
                    }
                }
            }
        }

        if ($selected[1] -eq 9 -or $selected[1] -eq -1) {
            & draw_buttons

            if ($script:zentoggle) {
                $script:zentoggle = $false
                & draw_extra_info
            }
        }

        & apply_highlighting 1
    }
})

$win.Icon = "$pwd/sudoku_favicon.ico"

$win.ShowDialog()
$script:timer.Enabled = $false
$script:timer = 0

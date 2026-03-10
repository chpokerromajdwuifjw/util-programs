Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$signature = @"
using System;
using System.Runtime.InteropServices;

public class Injector {

    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern IntPtr OpenProcess(int dwDesiredAccess, bool bInheritHandle, int dwProcessId);

    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern IntPtr VirtualAllocEx(IntPtr hProcess, IntPtr lpAddress, uint dwSize, uint flAllocationType, uint flProtect);

    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool WriteProcessMemory(IntPtr hProcess, IntPtr lpBaseAddress, byte[] lpBuffer, uint nSize, out IntPtr lpNumberOfBytesWritten);

    [DllImport("kernel32.dll")]
    public static extern IntPtr GetModuleHandle(string lpModuleName);

    [DllImport("kernel32.dll")]
    public static extern IntPtr GetProcAddress(IntPtr hModule, string procName);

    [DllImport("kernel32.dll")]
    public static extern IntPtr CreateRemoteThread(IntPtr hProcess, IntPtr lpThreadAttributes, uint dwStackSize,
        IntPtr lpStartAddress, IntPtr lpParameter, uint dwCreationFlags, IntPtr lpThreadId);
}
"@

Add-Type $signature

# Main Window
$form = New-Object System.Windows.Forms.Form
$form.Text = "DLL Injector"
$form.Size = New-Object System.Drawing.Size(420,200)
$form.StartPosition = "CenterScreen"

$processLabel = New-Object System.Windows.Forms.Label
$processLabel.Text = "Process:"
$processLabel.Location = New-Object System.Drawing.Point(10,20)
$form.Controls.Add($processLabel)

$processBox = New-Object System.Windows.Forms.TextBox
$processBox.Location = New-Object System.Drawing.Point(120,18)
$processBox.Width = 200
$form.Controls.Add($processBox)

$chooseBtn = New-Object System.Windows.Forms.Button
$chooseBtn.Text = "Select Process"
$chooseBtn.Location = New-Object System.Drawing.Point(120,45)
$form.Controls.Add($chooseBtn)

$dllLabel = New-Object System.Windows.Forms.Label
$dllLabel.Text = "DLL Path:"
$dllLabel.Location = New-Object System.Drawing.Point(10,85)
$form.Controls.Add($dllLabel)

$dllBox = New-Object System.Windows.Forms.TextBox
$dllBox.Location = New-Object System.Drawing.Point(120,83)
$dllBox.Width = 200
$form.Controls.Add($dllBox)

$browse = New-Object System.Windows.Forms.Button
$browse.Text = "Browse"
$browse.Location = New-Object System.Drawing.Point(330,80)
$form.Controls.Add($browse)

$inject = New-Object System.Windows.Forms.Button
$inject.Text = "Inject"
$inject.Location = New-Object System.Drawing.Point(160,120)
$form.Controls.Add($inject)

# File dialog
$dialog = New-Object System.Windows.Forms.OpenFileDialog
$dialog.Filter = "DLL files (*.dll)|*.dll"

$browse.Add_Click({
    if($dialog.ShowDialog() -eq "OK"){
        $dllBox.Text = $dialog.FileName
    }
})

# Process chooser window
$chooseBtn.Add_Click({

    $pform = New-Object System.Windows.Forms.Form
    $pform.Text = "Select Process"
    $pform.Size = New-Object System.Drawing.Size(400,400)

    $list = New-Object System.Windows.Forms.ListView
    $list.View = "Details"
    $list.FullRowSelect = $true
    $list.Dock = "Fill"

    $list.Columns.Add("Name",200) | Out-Null
    $list.Columns.Add("PID",100) | Out-Null

    Get-Process | Sort-Object ProcessName | ForEach-Object {
        $item = New-Object System.Windows.Forms.ListViewItem($_.ProcessName)
        $item.SubItems.Add($_.Id)
        $list.Items.Add($item) | Out-Null
    }

    $list.Add_DoubleClick({
        if($list.SelectedItems.Count -gt 0){
            $processBox.Text = $list.SelectedItems[0].SubItems[0].Text
            $pform.Close()
        }
    })

    $pform.Controls.Add($list)
    $pform.ShowDialog()

})

# Inject button
$inject.Add_Click({

    try{

        $proc = Get-Process $processBox.Text | Select-Object -First 1
        $dllPath = $dllBox.Text

        $procHandle = [Injector]::OpenProcess(0x1F0FFF, $false, $proc.Id)

        $dllBytes = [System.Text.Encoding]::ASCII.GetBytes($dllPath)

        $addr = [Injector]::VirtualAllocEx($procHandle,[IntPtr]::Zero,$dllBytes.Length,0x3000,0x40)

        [IntPtr]$out=[IntPtr]::Zero
        [Injector]::WriteProcessMemory($procHandle,$addr,$dllBytes,$dllBytes.Length,[ref]$out)

        $kernel=[Injector]::GetModuleHandle("kernel32.dll")
        $loadlib=[Injector]::GetProcAddress($kernel,"LoadLibraryA")

        [Injector]::CreateRemoteThread($procHandle,[IntPtr]::Zero,0,$loadlib,$addr,0,[IntPtr]::Zero)

        [System.Windows.Forms.MessageBox]::Show("DLL Injected!")

    } catch {
        [System.Windows.Forms.MessageBox]::Show("Injection Failed")
    }

})

$form.ShowDialog()
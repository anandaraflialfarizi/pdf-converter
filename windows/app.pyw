import locale
import os
from pathlib import Path
import threading
import wx
from converter import SUPPORTED, ConversionError, convert

ROOT = Path(__file__).resolve().parent
class Window(wx.Frame):
    def __init__(self):
        super().__init__(None, title="pdf Converter", size=(780, 470))
        self.SetIcon(wx.Icon(str(ROOT/"AppIcon.ico"), wx.BITMAP_TYPE_ICO))
        self.files = []
        self.busy = False
        self.config = wx.Config("pdf Converter")
        panel = wx.Panel(self)
        layout = wx.BoxSizer(wx.VERTICAL)
        bar = wx.BoxSizer(wx.HORIZONTAL)
        self.language = wx.Choice(panel, choices=["English","Bahasa Indonesia"])
        default = "id" if (locale.getlocale()[0] or "").lower().startswith(("id","indonesian")) else "en"
        self.language.SetSelection(int(self.config.Read("language",default) == "id"))
        self.add = wx.Button(panel)
        self.clear = wx.Button(panel)
        self.scan = wx.CheckBox(panel)
        for ctrl in (self.add,self.clear,self.scan,self.language):
            bar.Add(ctrl, 0, wx.ALL | wx.ALIGN_CENTER_VERTICAL, 4)
        layout.Add(bar,0,wx.ALL,6)
        self.list = wx.ListCtrl(panel, style=wx.LC_REPORT)
        self.list.InsertColumn(0,"File",width=270)
        self.list.InsertColumn(1,"Status",width=450)
        layout.Add(self.list,1,wx.EXPAND|wx.ALL,8)
        footer = wx.BoxSizer(wx.HORIZONTAL)
        self.credits = wx.Button(panel)
        self.save = wx.Button(panel)
        footer.Add(self.credits)
        footer.AddStretchSpacer()
        footer.Add(self.save)
        layout.Add(footer,0,wx.ALL|wx.EXPAND,8)
        panel.SetSizer(layout)
        self.add.Bind(wx.EVT_BUTTON,self.pick)
        self.clear.Bind(wx.EVT_BUTTON,self.clear_list)
        self.save.Bind(wx.EVT_BUTTON,self.run)
        self.credits.Bind(wx.EVT_BUTTON,lambda e: os.startfile(ROOT/"CREDITS.txt"))
        self.language.Bind(wx.EVT_CHOICE,self.labels)
        self.Bind(wx.EVT_CLOSE,self.close)
        self.labels()
        self.SetMinSize((660,330))

    def tr(self,en,id):
        return id if self.language.Selection == 1 else en

    def labels(self,event=None):
        if event:
            self.config.Write("language",self.tr("en","id"))
        for ctrl,en,id in [(self.add,"Add files…","Tambah file…"),(self.clear,"Clear list","Kosongkan"),(self.scan,"Scan photos","Scan dokumen dari foto"),(self.save,"Save PDFs…","Simpan PDF…"),(self.credits,"Third-party credits","Kredit pihak ketiga")]:
            ctrl.SetLabel(self.tr(en,id))
        self.save.Enable(bool(self.files) and not self.busy)
        self.clear.Enable(bool(self.files) and not self.busy)
        self.GetChildren()[0].Layout()

    def pick(self,event):
        pattern = ";".join("*."+ext for ext in sorted(SUPPORTED))
        with wx.FileDialog(self,self.add.Label,wildcard=self.tr("Supported files","File yang didukung")+"|"+pattern,style=wx.FD_OPEN|wx.FD_MULTIPLE|wx.FD_FILE_MUST_EXIST) as dlg:
            if dlg.ShowModal() == wx.ID_OK:
                for path in map(Path,dlg.GetPaths()):
                    if path not in self.files:
                        self.files.append(path)
                        self.list.InsertItem(self.list.GetItemCount(),path.name)
        self.labels()

    def clear_list(self,event):
        self.files.clear()
        self.list.DeleteAllItems()
        self.labels()

    def run(self,event):
        with wx.DirDialog(self,self.tr("Choose output folder","Pilih folder hasil")) as dlg:
            if dlg.ShowModal() != wx.ID_OK:
                return
            folder = Path(dlg.GetPath())
        scan = self.scan.Value
        indonesian = self.language.Selection == 1
        self.busy = True
        for ctrl in (self.add,self.clear,self.scan,self.language,self.save): ctrl.Disable()
        def worker():
            for row,path in enumerate(self.files):
                wx.CallAfter(self.list.SetItem,row,1,"Memproses…" if indonesian else "Converting…")
                try:
                    result = str(convert(path,folder,scan))
                except Exception as err:
                    reason = err.id if indonesian and isinstance(err,ConversionError) else str(err)
                    result = ("Gagal: " if indonesian else "Failed: ") + reason
                wx.CallAfter(self.list.SetItem,row,1,result)
            wx.CallAfter(self.done)
        threading.Thread(target=worker,daemon=True).start()

    def done(self):
        self.busy = False
        for ctrl in (self.add,self.scan,self.language): ctrl.Enable()
        self.labels()

    def close(self,event):
        if self.busy and event.CanVeto():
            wx.MessageBox(self.tr("Wait for conversion to finish.","Tunggu sampai konversi selesai."),"pdf Converter")
            event.Veto()
        else:
            event.Skip()

if __name__ == "__main__":
    app = wx.App(False)
    window = Window()
    window.Show()
    app.MainLoop()

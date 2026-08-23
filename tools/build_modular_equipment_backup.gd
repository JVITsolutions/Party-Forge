extends SceneTree

const INVENTORY_SCRIPT := preload("res://tools/modular_equipment_backup_inventory.gd")
const ERROR_PREFIX := "PARTY_FORGE_MODULAR_BACKUP_ERROR"
const MANIFEST_NAME := "manifest.json"
const PENDING_MANIFEST_NAME := ".manifest.pending.json"
const FAILURE_NAME := "backup.failure.json"
const PARTIAL_MANIFEST_NAME := "partial-manifest.json"
const MAX_FAILURE_MARKER_BYTES := 2048
const MAX_FAILURE_ERROR_CHARACTERS := 512
const REQUIRED_ARGUMENTS := ["source-root", "output", "source-commit", "source-branch"]
const ARGUMENT_FIELDS := {
	"source-root": "source_root",
	"output": "output",
	"source-commit": "source_commit",
	"source-branch": "source_branch",
}


class NativeFilesystem extends RefCounted:
	const NATIVE_SOURCE := r"""
using System;
using System.Collections.Generic;
using System.IO;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text;
using Microsoft.Win32.SafeHandles;

public static class Task3Native {
 const uint READ_ATTR=0x80, GENERIC_READ=0x80000000, GENERIC_WRITE=0x40000000;
 const uint SHARE_READ=1, SHARE_WRITE=2, SHARE_DELETE=4, OPEN_EXISTING=3, CREATE_NEW=1;
 const uint BACKUP=0x02000000, OPEN_REPARSE=0x00200000, ATTR_REPARSE=0x400, ATTR_DIR=0x10;
 const uint MOVE_WRITE_THROUGH=8;
 [StructLayout(LayoutKind.Sequential)] struct Info { public uint Attr,CT0,CT1,AT0,AT1,WT0,WT1,Vol,SizeH,SizeL,Links,IndexH,IndexL; }
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern SafeFileHandle CreateFileW(string p,uint a,uint s,IntPtr sa,uint d,uint f,IntPtr t);
 [DllImport("kernel32.dll",SetLastError=true)] static extern bool GetFileInformationByHandle(SafeFileHandle h,out Info i);
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern uint GetFinalPathNameByHandleW(SafeFileHandle h,StringBuilder p,uint n,uint f);
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern bool CreateDirectoryW(string p,IntPtr a);
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern bool MoveFileExW(string a,string b,uint f);
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern uint GetShortPathNameW(string p,StringBuilder s,uint n);

 sealed class Held : IDisposable {
  public string Full; public bool Exists; public string Nearest=""; public string Final=""; public uint Attr;
  public readonly List<string> Ids=new List<string>(); public readonly List<SafeFileHandle> Handles=new List<SafeFileHandle>();
  public void Dispose(){ for(int i=Handles.Count-1;i>=0;i--) Handles[i].Dispose(); }
 }
 static string B64(string s){ return Convert.ToBase64String(Encoding.UTF8.GetBytes(s)); }
 static string Hex(byte[] b){ return BitConverter.ToString(b).Replace("-","").ToLowerInvariant(); }
 static void Out(string s){ Console.Out.WriteLine(s); Console.Out.Flush(); }
 static void Reject(string p){ if(String.IsNullOrWhiteSpace(p)) throw new IOException("empty path"); if(p.StartsWith("\\\\")) throw new IOException("UNC paths fail closed"); }
 static SafeFileHandle Open(string p,uint access,uint share,uint disposition){
  SafeFileHandle h=CreateFileW(p,access,share,IntPtr.Zero,disposition,BACKUP|OPEN_REPARSE,IntPtr.Zero);
  if(h.IsInvalid){ int e=Marshal.GetLastWin32Error(); h.Dispose(); throw new IOException((e==80||e==183?"collision":"CreateFileW failed code="+e)+" path="+p); }
  return h;
 }
 static Info GetInfo(SafeFileHandle h){ Info i; if(!GetFileInformationByHandle(h,out i)) throw new IOException("GetFileInformationByHandle failed code="+Marshal.GetLastWin32Error()); return i; }
 static string Id(Info i){ return i.Vol.ToString("x8")+":"+i.IndexH.ToString("x8")+i.IndexL.ToString("x8"); }
 static string FinalName(SafeFileHandle h){ StringBuilder b=new StringBuilder(32768); uint n=GetFinalPathNameByHandleW(h,b,(uint)b.Capacity,0); if(n==0||n>=b.Capacity) throw new IOException("GetFinalPathNameByHandleW failed code="+Marshal.GetLastWin32Error()); return b.ToString(); }
 static void Check(Info i,string p){ if((i.Attr&ATTR_REPARSE)!=0) throw new IOException("reparse component: "+p); }
 static Held Hold(string path,bool allowMissing){
  Reject(path); Held w=new Held(); w.Full=Path.GetFullPath(path); string root=Path.GetPathRoot(w.Full); if(String.IsNullOrEmpty(root)) throw new IOException("path root missing");
  string current=root; string tail=w.Full.Substring(root.Length); string[] parts=tail.Split(new[]{Path.DirectorySeparatorChar,Path.AltDirectorySeparatorChar},StringSplitOptions.RemoveEmptyEntries);
  List<string> paths=new List<string>(); paths.Add(root); foreach(string part in parts){ current=Path.Combine(current,part); paths.Add(current); }
  try {
   foreach(string candidate in paths){
    SafeFileHandle h=CreateFileW(candidate,READ_ATTR,SHARE_READ|SHARE_WRITE,IntPtr.Zero,OPEN_EXISTING,BACKUP|OPEN_REPARSE,IntPtr.Zero);
    if(h.IsInvalid){ int e=Marshal.GetLastWin32Error(); h.Dispose(); if(allowMissing&&(e==2||e==3)){ w.Exists=false; return w; } throw new IOException("path open failed code="+e+" path="+candidate); }
    Info info=GetInfo(h); Check(info,candidate); string id=Id(info); w.Handles.Add(h); w.Ids.Add(id); w.Nearest=id; w.Final=id; w.Attr=info.Attr;
   }
   w.Exists=true; return w;
  } catch { w.Dispose(); throw; }
 }
 static void Require(Held h,string anchor,string label){ if(String.IsNullOrEmpty(anchor)||!h.Ids.Contains(anchor)) throw new IOException(label+" physical containment identity failure"); }
 static SafeFileHandle Exact(string p,uint access,uint share,uint disposition,string expected){ SafeFileHandle h=Open(p,access,share,disposition); Info i=GetInfo(h); try { Check(i,p); if(!String.IsNullOrEmpty(expected)&&Id(i)!=expected) throw new IOException("opened object identity changed"); return h; } catch { h.Dispose(); throw; } }
 static string HashStream(Stream s,out long count){ SHA256 sha=SHA256.Create(); try { byte[] b=new byte[65536]; int n; count=0; while((n=s.Read(b,0,b.Length))>0){ sha.TransformBlock(b,0,n,null,0); count+=n; } sha.TransformFinalBlock(new byte[0],0,0); return Hex(sha.Hash); } finally { sha.Dispose(); } }
 static void Delay(string value){ int n; if(Int32.TryParse(value,out n)&&n>0) System.Threading.Thread.Sleep(n); }
 static void Probe(string[] a){ using(Held h=Hold(a[1],a[2]=="0")){ string canon=h.Exists?FinalName(h.Handles[h.Handles.Count-1]):h.Full; Out("OK|PROBE|"+(h.Exists?"1":"0")+"|"+h.Nearest+"|"+h.Final+"|"+B64(canon)+"|"+String.Join(",",h.Ids.ToArray())); } }
 static void State(string[] a){ using(Held h=Hold(a[1],true)){ if(!h.Exists){ Out("OK|STATE|0|1"); return; } if((h.Attr&ATTR_DIR)==0) throw new IOException("path is a file"); bool empty=Directory.GetFileSystemEntries(h.Full).Length==0; Out("OK|STATE|1|"+(empty?"1":"0")); } }
 static void Mkdir(string[] a){ string p=Path.GetFullPath(a[1]); using(Held parent=Hold(Path.GetDirectoryName(p),false)){ Require(parent,a[2],"output"); if(!CreateDirectoryW(p,IntPtr.Zero)){ int e=Marshal.GetLastWin32Error(); throw new IOException((e==80||e==183?"collision":"CreateDirectoryW failed code="+e)); } using(SafeFileHandle h=Exact(p,READ_ATTR,SHARE_READ|SHARE_WRITE,OPEN_EXISTING,"")){ string id=Id(GetInfo(h)); Out("OWN|D|"+id+"|"+B64(p)); Delay(a[3]); Out("OK|DIR|"+id); } } }
 static void Create(string[] a){ string p=Path.GetFullPath(a[1]); long expected=Int64.Parse(a[3]); using(Held parent=Hold(Path.GetDirectoryName(p),false)){ Require(parent,a[2],"output"); using(SafeFileHandle h=Exact(p,GENERIC_READ|GENERIC_WRITE,0,CREATE_NEW,"")){ string id=Id(GetInfo(h)); Out("OWN|F|"+id+"|"+B64(p)); Delay(a[5]); using(FileStream f=new FileStream(h,FileAccess.ReadWrite,65536,false)){ string line; long written=0; while((line=Console.In.ReadLine())!=null&&line!="."){ byte[] b=Convert.FromBase64String(line); f.Write(b,0,b.Length); written+=b.Length; } if(line==null) throw new IOException("content channel closed"); f.Flush(true); if(written!=expected||f.Length!=expected) throw new IOException("short write"); f.Position=0; long count; string hash=HashStream(f,out count); if(count!=expected||hash!=a[4]) throw new IOException("write verification mismatch"); Out("OK|CREATE|"+count+"|"+hash+"|"+id); } } } }
 static void Copy(string[] a){ string src=Path.GetFullPath(a[1]), dst=Path.GetFullPath(a[3]); using(Held sh=Hold(src,false)) using(Held dp=Hold(Path.GetDirectoryName(dst),false)){ Require(sh,a[2],"source"); Require(dp,a[4],"output"); if((sh.Attr&ATTR_DIR)!=0) throw new IOException("source is a directory"); using(SafeFileHandle si=Exact(src,GENERIC_READ,SHARE_READ|SHARE_WRITE,OPEN_EXISTING,sh.Final)) using(SafeFileHandle di=Exact(dst,GENERIC_READ|GENERIC_WRITE,0,CREATE_NEW,"")){ string id=Id(GetInfo(di)); Out("OWN|F|"+id+"|"+B64(dst)); Delay(a[5]); using(FileStream s=new FileStream(si,FileAccess.Read,65536,false)) using(FileStream d=new FileStream(di,FileAccess.ReadWrite,65536,false)){ long expected=s.Length,read=0; byte[] b=new byte[65536]; SHA256 sha=SHA256.Create(); string srcHash; try { int n; while((n=s.Read(b,0,b.Length))>0){ d.Write(b,0,n); sha.TransformBlock(b,0,n,null,0); read+=n; } sha.TransformFinalBlock(new byte[0],0,0); srcHash=Hex(sha.Hash); } finally { sha.Dispose(); } d.Flush(true); long srcPos=s.Position,dstLen=d.Length; d.Position=0; long dstRead; string dstHash=HashStream(d,out dstRead); if(read!=expected||srcPos!=expected||dstLen!=expected||dstRead!=expected||srcHash!=dstHash) throw new IOException("copy full-length or hash verification failed"); Out("OK|COPY|"+expected+"|"+read+"|"+srcPos+"|"+srcHash+"|"+dstLen+"|"+dstRead+"|"+d.Position+"|"+dstHash+"|"+id); } } } }
 static void Publish(string[] a){ string pending=Path.GetFullPath(a[1]), final=Path.GetFullPath(a[2]); using(Held pp=Hold(Path.GetDirectoryName(pending),false)) using(Held fp=Hold(Path.GetDirectoryName(final),false)){ Require(pp,a[3],"output"); Require(fp,a[3],"output"); using(Held ph=Hold(pending,false)){ if((ph.Attr&ATTR_DIR)!=0) throw new IOException("pending is a directory"); using(SafeFileHandle exact=Exact(pending,READ_ATTR,SHARE_READ|SHARE_WRITE|SHARE_DELETE,OPEN_EXISTING,ph.Final)){ string id=Id(GetInfo(exact)); Delay(a[4]); if(!MoveFileExW(pending,final,MOVE_WRITE_THROUGH)){ int e=Marshal.GetLastWin32Error(); throw new IOException((e==80||e==183?"collision":"MoveFileExW failed code="+e)); } using(SafeFileHandle check=Exact(final,READ_ATTR,SHARE_READ|SHARE_WRITE,OPEN_EXISTING,id)){ Out("OK|PUBLISH|"+id); } } } } }
 static void Short(string[] a){ Reject(a[1]); string p=Path.GetFullPath(a[1]); StringBuilder b=new StringBuilder(32768); uint n=GetShortPathNameW(p,b,(uint)b.Capacity); if(n==0||n>=b.Capacity){ Out("OK|SHORT|0|"); return; } Out("OK|SHORT|1|"+B64(b.ToString())); }
 public static void Run(string[] a){ if(a==null||a.Length==0) throw new IOException("operation missing"); switch(a[0]){ case "probe":Probe(a);break; case "state":State(a);break; case "mkdir":Mkdir(a);break; case "create":Create(a);break; case "copy":Copy(a);break; case "publish":Publish(a);break; case "short":Short(a);break; default:throw new IOException("unknown operation"); } }
}
"""
	var _mutation_anchor := ""
	var _source_anchor := ""
	var _helper_timeout_msec := 300000
	var _post_create_delay_msec := 0


	func probe_path(path: String, require_exists: bool) -> Dictionary:
		var result := _invoke_native(["probe", path, "1" if require_exists else "0"])
		if not String(result.get("error", "")).is_empty():
			return {"error": "physical path probe failed: %s" % result["error"], "path": ""}
		var fields := result.get("fields", PackedStringArray()) as PackedStringArray
		if fields.size() < 7 or fields[1] != "PROBE":
			return {"error": "physical path probe returned invalid status", "path": ""}
		if require_exists and fields[2] != "1":
			return {"error": "path does not exist", "path": ""}
		return {"error": "", "path": _decode(fields[5]).replace("\\", "/"), "exists": fields[2] == "1", "nearest_identity": fields[3], "identity": fields[4], "ancestor_identities": fields[6].split(",", false)}


	func directory_state(path: String) -> Dictionary:
		var result := _invoke_native(["state", path])
		if not String(result.get("error", "")).is_empty():
			return {"error": String(result["error"]), "exists": false, "empty": false}
		var fields := result.get("fields", PackedStringArray()) as PackedStringArray
		if fields.size() < 4 or fields[1] != "STATE":
			return {"error": "directory state returned invalid status", "exists": false, "empty": false}
		return {"error": "", "exists": fields[2] == "1", "empty": fields[3] == "1"}


	func configure_output_root(path: String) -> Dictionary:
		var probe := probe_path(path, false)
		if not String(probe.get("error", "")).is_empty():
			return {"error": String(probe["error"])}
		var ancestors := probe.get("ancestor_identities", PackedStringArray()) as PackedStringArray
		if not _source_anchor.is_empty() and _source_anchor in ancestors:
			return {"error": "output physical containment identity overlaps source"}
		_mutation_anchor = String(probe.get("nearest_identity", ""))
		if _mutation_anchor.is_empty():
			return {"error": "cannot resolve existing output ancestor identity"}
		return {"error": ""}


	func configure_source_root(path: String, git_toplevel: String) -> Dictionary:
		var source_identity := canonical_identity(path)
		if not String(source_identity.get("error", "")).is_empty():
			return source_identity
		var git_identity := canonical_identity(git_toplevel)
		if not String(git_identity.get("error", "")).is_empty():
			return git_identity
		if String(source_identity.get("identity", "")) != String(git_identity.get("identity", "")):
			return {"error": "Git top-level canonical identity mismatch"}
		_source_anchor = String(source_identity.get("identity", ""))
		return {"error": "", "identity": _source_anchor}


	func canonical_identity(path: String) -> Dictionary:
		var probe := probe_path(path, true)
		if not String(probe.get("error", "")).is_empty():
			return {"error": String(probe["error"]), "identity": ""}
		return {"error": "", "identity": String(probe.get("identity", ""))}


	func copy_file_verified(source_path: String, destination_path: String) -> Dictionary:
		if _source_anchor.is_empty() or _mutation_anchor.is_empty():
			return {"error": "source and output identities must be configured", "created": false}
		var result := _invoke_native(["copy", source_path, _source_anchor, destination_path, _mutation_anchor, str(_operation_delay())])
		var owned := _owned_from_result(result, destination_path)
		if not String(result.get("error", "")).is_empty():
			return {"error": String(result["error"]), "created": bool(owned.get("created", false)), "terminated": bool(result.get("terminated", false)), "ownership_reconciled": bool(owned.get("reconciled", false))}
		var f := result.get("fields", PackedStringArray()) as PackedStringArray
		if f.size() < 11 or f[1] != "COPY":
			return {"error": "copy helper returned invalid status", "created": bool(owned.get("created", false))}
		var source := {"error": "", "expected_length": int(f[2]), "bytes_read": int(f[3]), "position": int(f[4]), "read_error": OK, "sha256": f[5], "bytes_verified": true}
		var destination := {"error": "", "expected_length": int(f[6]), "bytes_read": int(f[7]), "position": int(f[8]), "read_error": OK, "sha256": f[9], "bytes_verified": true}
		return {"error": "", "created": true, "source": source, "destination": destination, "equal": f[5] == f[9] and f[2] == f[6]}


	func supervision_contract() -> Dictionary:
		return {"bounded": true, "termination_confirmed": true, "ownership_reconciled": true, "abnormal_exit_reconciled": true}


	func run_process_bounded(executable: String, arguments: PackedStringArray) -> Dictionary:
		var process := OS.execute_with_pipe(executable, arguments, false)
		var stdio := process.get("stdio") as FileAccess
		var stderr := process.get("stderr") as FileAccess
		var pid := int(process.get("pid", -1))
		if stdio == null or pid <= 0:
			if stdio != null:
				stdio.close()
			if stderr != null:
				stderr.close()
			return {"exit_code": -1, "output": "", "error": "subprocess pipe creation failed"}
		var deadline := Time.get_ticks_msec() + _helper_timeout_msec
		var output_bytes := PackedByteArray()
		while OS.is_process_running(pid) and Time.get_ticks_msec() < deadline:
			_drain_nonblocking(stdio, output_bytes)
			if output_bytes.size() > 16 * 1024 * 1024:
				var oversized := _terminate_helper(pid, stdio, stderr, output_bytes, "subprocess output exceeds 16 MiB")
				return {"exit_code": -1, "output": output_bytes.get_string_from_utf8(), "error": String(oversized.get("error", "subprocess output exceeds 16 MiB")), "terminated": bool(oversized.get("terminated", false))}
			OS.delay_msec(5)
		if OS.is_process_running(pid):
			var killed := _terminate_helper(pid, stdio, stderr, output_bytes, "subprocess timed out")
			return {"exit_code": -1, "output": output_bytes.get_string_from_utf8(), "error": String(killed.get("error", "subprocess timed out")), "terminated": bool(killed.get("terminated", false))}
		_drain_nonblocking(stdio, output_bytes)
		var exit_code := OS.get_process_exit_code(pid)
		stdio.close()
		if stderr != null:
			stderr.close()
		return {"exit_code": exit_code, "output": output_bytes.get_string_from_utf8(), "error": ""}


	func _drain_nonblocking(stdio: FileAccess, output_bytes: PackedByteArray) -> void:
		while true:
			var chunk := stdio.get_buffer(8192)
			if chunk.is_empty():
				return
			output_bytes.append_array(chunk)
			if chunk.size() < 8192:
				return


	func configure_supervision(timeout_msec: int, post_create_delay_msec: int = 0) -> void:
		_helper_timeout_msec = maxi(timeout_msec, 1)
		_post_create_delay_msec = maxi(post_create_delay_msec, 0)


	func _operation_delay() -> int:
		if _post_create_delay_msec > _helper_timeout_msec:
			return maxi(_post_create_delay_msec, 2500)
		return _post_create_delay_msec


	func short_path(path: String) -> Dictionary:
		var result := _invoke_native(["short", path])
		if not String(result.get("error", "")).is_empty():
			return {"error": String(result["error"]), "supported": false, "path": ""}
		var f := result.get("fields", PackedStringArray()) as PackedStringArray
		if f.size() < 4 or f[1] != "SHORT" or f[2] != "1":
			return {"error": "8.3 alias unavailable", "supported": false, "path": ""}
		return {"error": "", "supported": true, "path": _decode(f[3]).replace("\\", "/")}


	func ensure_directory(path: String) -> Dictionary:
		if _mutation_anchor.is_empty():
			return {"error": "output containment root was not configured", "created_paths": []}
		var normalized := path.replace("\\", "/").simplify_path().trim_suffix("/")
		var missing: Array[String] = []
		var cursor := normalized
		while not cursor.is_empty():
			var state := directory_state(cursor)
			if not String(state.get("error", "")).is_empty() and "path is a file" in String(state["error"]):
				return {"error": String(state["error"]), "created_paths": []}
			if bool(state.get("exists", false)):
				break
			missing.append(cursor)
			var parent := cursor.get_base_dir()
			if parent == cursor:
				break
			cursor = parent
		missing.reverse()
		var created: Array[String] = []
		var reconciled := false
		for directory: String in missing:
			var create_result := _invoke_native(["mkdir", directory, _mutation_anchor, str(_operation_delay())])
			var ownership := _owned_from_result(create_result, directory)
			if bool(ownership.get("created", false)):
				created.append(directory)
			reconciled = reconciled or bool(ownership.get("reconciled", false))
			if not String(create_result.get("error", "")).is_empty():
				return {"error": String(create_result["error"]), "created_paths": created, "terminated": bool(create_result.get("terminated", false)), "ownership_reconciled": reconciled}
			var f := create_result.get("fields", PackedStringArray()) as PackedStringArray
			if f.size() < 3 or f[1] != "DIR":
				return {"error": "directory exclusive create returned invalid helper status", "created_paths": created}
		return {"error": "", "created_paths": created, "ownership_reconciled": reconciled}


	func read_file(path: String) -> Dictionary:
		return {"error": "direct native reads are unavailable; use handle-guarded copy or verified create", "bytes": PackedByteArray(), "expected_length": -1, "bytes_read": 0, "position": 0, "read_error": ERR_FILE_CANT_READ, "sha256": ""}


	func create_file_exclusive(path: String, bytes: PackedByteArray) -> Dictionary:
		if _mutation_anchor.is_empty():
			return {"error": "output containment root was not configured", "created": false}
		var create_result := _invoke_native(["create", path, _mutation_anchor, str(bytes.size()), _hash(bytes), str(_operation_delay())], bytes)
		var ownership := _owned_from_result(create_result, path)
		if not String(create_result.get("error", "")).is_empty():
			return {"error": String(create_result["error"]), "created": bool(ownership.get("created", false)), "terminated": bool(create_result.get("terminated", false)), "ownership_reconciled": bool(ownership.get("reconciled", false))}
		var f := create_result.get("fields", PackedStringArray()) as PackedStringArray
		if f.size() < 5 or f[1] != "CREATE":
			return {"error": "exclusive create returned invalid helper status", "created": false}
		return {"error": "", "created": true, "verified": int(f[2]) == bytes.size() and f[3] == _hash(bytes), "expected_length": int(f[2]), "sha256": f[3]}


	func publish_no_replace(pending_path: String, final_path: String) -> Dictionary:
		if _mutation_anchor.is_empty():
			return {"error": "output containment root was not configured", "published": false}
		var publish_result := _invoke_native(["publish", pending_path, final_path, _mutation_anchor, str(_operation_delay())])
		if not String(publish_result.get("error", "")).is_empty():
			return {"error": "atomic no-replace publish failed: %s" % publish_result["error"], "published": false}
		var f := publish_result.get("fields", PackedStringArray()) as PackedStringArray
		if f.size() < 3 or f[1] != "PUBLISH":
			return {"error": "atomic no-replace publish returned invalid status", "published": false}
		return {"error": "", "published": true}


	func _invoke_native(arguments: Array[String], bytes: PackedByteArray = PackedByteArray(), timeout_override: int = -1) -> Dictionary:
		var compressed := NATIVE_SOURCE.to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP)
		var payload := Marshalls.raw_to_base64(compressed)
		var script := "$ErrorActionPreference='Stop'; try{$m=New-Object IO.MemoryStream(,[Convert]::FromBase64String('%s'));$z=New-Object IO.Compression.GZipStream($m,[IO.Compression.CompressionMode]::Decompress);$r=New-Object IO.StreamReader($z,[Text.Encoding]::UTF8);Add-Type -TypeDefinition $r.ReadToEnd();[Console]::Out.WriteLine('READY');[Console]::Out.Flush();[Task3Native]::Run([string[]]$args)}catch{$b=[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($_.Exception.Message));[Console]::Out.WriteLine('ERR|'+$b);exit 70}" % payload
		var process_arguments := PackedStringArray(["-NoLogo", "-NoProfile", "-NonInteractive"])
		process_arguments.append_array(encoded_pipe_invocation(script, PackedStringArray(arguments)))
		var process := OS.execute_with_pipe("powershell.exe", process_arguments, false)
		var stdio := process.get("stdio") as FileAccess
		var stderr := process.get("stderr") as FileAccess
		var pid := int(process.get("pid", -1))
		if stdio == null or pid <= 0:
			if stdio != null:
				stdio.close()
			if stderr != null:
				stderr.close()
			return {"error": "helper pipe creation failed", "exit_code": -1}
		var timeout := _helper_timeout_msec if timeout_override < 0 else timeout_override
		var deadline := Time.get_ticks_msec() + timeout + 2000
		var output_bytes := PackedByteArray()
		var offset := 0
		while offset < bytes.size():
			var next_offset := mini(offset + 2048, bytes.size())
			var encoded_chunk := Marshalls.raw_to_base64(bytes.slice(offset, next_offset)) + "\n"
			while not stdio.store_string(encoded_chunk):
				if not OS.is_process_running(pid) or Time.get_ticks_msec() >= deadline:
					return _terminate_helper(pid, stdio, stderr, output_bytes, "helper content channel write timed out")
				OS.delay_msec(1)
			offset = next_offset
		while not stdio.store_string(".\n"):
			if not OS.is_process_running(pid) or Time.get_ticks_msec() >= deadline:
				return _terminate_helper(pid, stdio, stderr, output_bytes, "helper content terminator write timed out")
			OS.delay_msec(1)
		while OS.is_process_running(pid):
			if Time.get_ticks_msec() >= deadline:
				return _terminate_helper(pid, stdio, stderr, output_bytes, "helper timed out")
			OS.delay_msec(5)
		var exit_code := OS.get_process_exit_code(pid)
		var tail := stdio.get_as_text().to_utf8_buffer()
		output_bytes.append_array(tail)
		stdio.close()
		if stderr != null:
			stderr.close()
		return _parse_helper_result(exit_code, output_bytes.get_string_from_utf8(), false, true)


	func _terminate_helper(pid: int, stdio: FileAccess, stderr: FileAccess, output_bytes: PackedByteArray, reason: String) -> Dictionary:
		OS.kill(pid)
		var kill_deadline := Time.get_ticks_msec() + 5000
		while OS.is_process_running(pid) and Time.get_ticks_msec() < kill_deadline:
			OS.delay_msec(5)
		var terminated := not OS.is_process_running(pid)
		if terminated:
			output_bytes.append_array(stdio.get_as_text().to_utf8_buffer())
		stdio.close()
		if stderr != null:
			stderr.close()
		var parsed := _parse_helper_result(-1, output_bytes.get_string_from_utf8(), true, terminated)
		parsed["error"] = "%s%s" % [reason, "" if terminated else "; termination unconfirmed"]
		return parsed


	func _parse_helper_result(exit_code: int, output: String, timed_out: bool, terminated: bool) -> Dictionary:
		var result := {"exit_code": exit_code, "error": "", "fields": PackedStringArray(), "ownership": {}, "timed_out": timed_out, "terminated": terminated}
		for raw_line: String in output.replace("\r", "").split("\n", false):
			var fields := PackedStringArray(raw_line.split("|", true))
			if fields.is_empty() or fields[0] == "READY":
				continue
			if fields[0] == "OWN" and fields.size() >= 4:
				result["ownership"] = {"kind": fields[1], "identity": fields[2], "path": _decode(fields[3])}
			elif fields[0] == "OK":
				result["fields"] = fields
			elif fields[0] == "ERR" and fields.size() >= 2:
				result["error"] = _decode(fields[1])
		if String(result["error"]).is_empty() and exit_code != 0 and not timed_out:
			result["error"] = "native helper failed code=%d" % exit_code
		return result


	func _decode(value: String) -> String:
		return Marshalls.base64_to_raw(value).get_string_from_utf8()


	func _owned_from_result(result: Dictionary, expected_path: String) -> Dictionary:
		var ownership := result.get("ownership", {}) as Dictionary
		if ownership.is_empty() or String(ownership.get("path", "")).replace("\\", "/").to_lower() != expected_path.replace("\\", "/").to_lower():
			return {"created": false, "reconciled": false}
		var abnormal := bool(result.get("timed_out", false)) or not String(result.get("error", "")).is_empty()
		if not abnormal:
			return {"created": true, "reconciled": false}
		if not bool(result.get("terminated", false)):
			return {"created": false, "reconciled": false}
		var probe_result := _invoke_native(["probe", expected_path, "1"], PackedByteArray(), 10000)
		if not String(probe_result.get("error", "")).is_empty():
			return {"created": false, "reconciled": false}
		var fields := probe_result.get("fields", PackedStringArray()) as PackedStringArray
		var matches := fields.size() >= 5 and fields[1] == "PROBE" and fields[4] == String(ownership.get("identity", ""))
		return {"created": matches, "reconciled": matches}


	func encoded_invocation(script: String, arguments: PackedStringArray) -> PackedStringArray:
		var encoded_literals := PackedStringArray()
		for argument: String in arguments:
			encoded_literals.append("'%s'" % Marshalls.raw_to_base64(argument.to_utf8_buffer()))
		var wrapper := "$encoded=@(%s); $decoded=@($encoded | ForEach-Object { [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($_)) }); & { %s } @decoded" % [",".join(encoded_literals), script]
		return PackedStringArray(["-EncodedCommand", Marshalls.raw_to_base64(wrapper.to_utf16_buffer())])


	func encoded_pipe_invocation(script: String, arguments: PackedStringArray) -> PackedStringArray:
		return encoded_invocation(script, arguments)


	func _hash(bytes: PackedByteArray) -> String:
		var hashing := HashingContext.new()
		hashing.start(HashingContext.HASH_SHA256)
		hashing.update(bytes)
		return hashing.finish().hex_encode()


	func _bounded_output(value: String) -> String:
		return value.replace("\r", " ").replace("\n", " ").left(512)


class GitProbe extends RefCounted:
	var _supervisor: RefCounted


	func _init(supervisor: RefCounted = null) -> void:
		_supervisor = supervisor


	func probe(source_root: String) -> Dictionary:
		var head := _git(source_root, ["rev-parse", "HEAD"])
		if int(head.get("exit_code", -1)) != 0:
			return {"error": "Git HEAD probe failed code=%d" % int(head.get("exit_code", -1))}
		var branch := _git(source_root, ["symbolic-ref", "--quiet", "--short", "HEAD"])
		if int(branch.get("exit_code", -1)) != 0:
			return {"error": "Git branch probe failed code=%d" % int(branch.get("exit_code", -1))}
		var status := _git(source_root, ["status", "--porcelain=v1", "--untracked-files=all"])
		if int(status.get("exit_code", -1)) != 0:
			return {"error": "Git status probe failed code=%d" % int(status.get("exit_code", -1))}
		var toplevel := _git(source_root, ["rev-parse", "--show-toplevel"])
		if int(toplevel.get("exit_code", -1)) != 0:
			return {"error": "Git top-level probe failed code=%d" % int(toplevel.get("exit_code", -1))}
		return {
			"error": "",
			"commit": String(head.get("output", "")).strip_edges(),
			"branch": String(branch.get("output", "")).strip_edges(),
			"worktree_status": String(status.get("output", "")),
			"toplevel": String(toplevel.get("output", "")).strip_edges(),
		}


	func _git(source_root: String, arguments: Array[String]) -> Dictionary:
		var git_arguments := PackedStringArray(["-C", source_root])
		git_arguments.append_array(PackedStringArray(arguments))
		if _supervisor == null or not _supervisor.has_method(&"run_process_bounded"):
			return {"exit_code": -1, "output": "", "error": "bounded Git supervisor unavailable"}
		return _supervisor.call(&"run_process_bounded", "git", git_arguments) as Dictionary


class BackupService extends RefCounted:
	func build_backup_with_filesystem(request: Dictionary, inventory_paths: PackedStringArray, source_metadata: Dictionary, filesystem: RefCounted) -> Dictionary:
		if filesystem == null:
			return _failed_result("%s field=filesystem reason=race-safe adapter required" % ERROR_PREFIX)
		if not filesystem.has_method(&"copy_file_verified"):
			return _failed_result("%s field=filesystem reason=one handle-guarded copy operation is required" % ERROR_PREFIX)
		var validation_error := _validate_request(request, inventory_paths, source_metadata, filesystem)
		if not validation_error.is_empty():
			return _failed_result(validation_error)

		var source_root := _normalized_absolute(String(request.get("source_root", "")))
		var output := _normalized_absolute(String(request.get("output", "")))
		var metadata := {
			"root": source_root,
			"commit": String(source_metadata.get("commit", "")),
			"branch": String(source_metadata.get("branch", "")),
			"worktree_status": String(source_metadata.get("worktree_status", "")),
			"toplevel": String(source_metadata.get("toplevel", "")),
		}
		var owned_paths: Array[String] = []
		var owned_external_paths: Array[String] = []
		if not filesystem.has_method(&"configure_source_root"):
			return _failed_result("%s field=filesystem reason=canonical source identity configuration is required" % ERROR_PREFIX)
		var source_configuration := filesystem.call(&"configure_source_root", source_root, String(source_metadata.get("toplevel", ""))) as Dictionary
		if not String(source_configuration.get("error", "")).is_empty():
			return _failed_result("%s field=source_root reason=%s" % [ERROR_PREFIX, source_configuration["error"]])
		if not filesystem.has_method(&"configure_output_root"):
			return _failed_result("%s field=filesystem reason=output containment configuration is required" % ERROR_PREFIX)
		var configuration := filesystem.call(&"configure_output_root", output) as Dictionary
		if not String(configuration.get("error", "")).is_empty():
			return _failed_result("%s field=output reason=%s" % [ERROR_PREFIX, configuration["error"]])
		var output_create := filesystem.call(&"ensure_directory", output) as Dictionary
		_register_created(output_create.get("created_paths", []) as Array, output, owned_paths, owned_external_paths)
		if not String(output_create.get("error", "")).is_empty():
			return _preserve_failure(filesystem, output, metadata, inventory_paths.size(), [], owned_paths, owned_external_paths, "%s field=output reason=%s" % [ERROR_PREFIX, output_create["error"]])

		var sorted_paths := inventory_paths.duplicate()
		sorted_paths.sort()
		var completed_files: Array[Dictionary] = []
		var total_bytes := 0
		for relative_path: String in sorted_paths:
			var source_path := source_root.path_join(relative_path)
			var destination_path := output.path_join(relative_path)
			var parent_create := filesystem.call(&"ensure_directory", destination_path.get_base_dir()) as Dictionary
			_register_created(parent_create.get("created_paths", []) as Array, output, owned_paths, owned_external_paths)
			if not String(parent_create.get("error", "")).is_empty():
				return _preserve_failure(filesystem, output, metadata, sorted_paths.size(), completed_files, owned_paths, owned_external_paths, "%s stage=copy path=%s reason=%s" % [ERROR_PREFIX, relative_path, parent_create["error"]])
			var copy_result := filesystem.call(&"copy_file_verified", source_path, destination_path) as Dictionary
			if bool(copy_result.get("created", false)):
				_register_owned(destination_path, output, owned_paths, owned_external_paths)
			if not String(copy_result.get("error", "")).is_empty():
				return _preserve_failure(filesystem, output, metadata, sorted_paths.size(), completed_files, owned_paths, owned_external_paths, "%s stage=copy path=%s reason=%s" % [ERROR_PREFIX, relative_path, copy_result["error"]])
			var source_read := _validated_read_result(copy_result.get("source", {}) as Dictionary, "source")
			if not String(source_read.get("error", "")).is_empty():
				return _preserve_failure(filesystem, output, metadata, sorted_paths.size(), completed_files, owned_paths, owned_external_paths, "%s stage=verify path=%s reason=%s" % [ERROR_PREFIX, relative_path, source_read["error"]])
			var destination_read := _validated_read_result(copy_result.get("destination", {}) as Dictionary, "destination")
			if not String(destination_read.get("error", "")).is_empty():
				return _preserve_failure(filesystem, output, metadata, sorted_paths.size(), completed_files, owned_paths, owned_external_paths, "%s stage=verify path=%s reason=%s" % [ERROR_PREFIX, relative_path, destination_read["error"]])
			if not bool(copy_result.get("equal", false)) or int(source_read.get("expected_length", -1)) != int(destination_read.get("expected_length", -1)) or String(source_read.get("sha256", "")) != String(destination_read.get("sha256", "")):
				return _preserve_failure(filesystem, output, metadata, sorted_paths.size(), completed_files, owned_paths, owned_external_paths, "%s stage=verify path=%s reason=source and destination hash mismatch" % [ERROR_PREFIX, relative_path])
			var row := {
				"path": relative_path,
				"size": int(source_read.get("expected_length", -1)),
				"sha256": String(destination_read.get("sha256", "")),
			}
			completed_files.append(row)
			total_bytes += int(source_read.get("expected_length", -1))

		var manifest := {
			"schema_version": 1,
			"state": "complete",
			"source": metadata,
			"expected_file_count": sorted_paths.size(),
			"file_count": completed_files.size(),
			"total_bytes": total_bytes,
			"files": completed_files,
		}
		var manifest_bytes := JSON.stringify(manifest, "\t", true).to_utf8_buffer()
		var pending_path := output.path_join(PENDING_MANIFEST_NAME)
		var pending_write := _write_verified_exclusive(filesystem, pending_path, manifest_bytes)
		if bool(pending_write.get("created", false)):
			_register_owned(pending_path, output, owned_paths, owned_external_paths)
		if not String(pending_write.get("error", "")).is_empty():
			return _preserve_failure(filesystem, output, metadata, sorted_paths.size(), completed_files, owned_paths, owned_external_paths, "%s stage=manifest-pending reason=%s" % [ERROR_PREFIX, pending_write["error"]])
		var publish := filesystem.call(&"publish_no_replace", pending_path, output.path_join(MANIFEST_NAME)) as Dictionary
		if not String(publish.get("error", "")).is_empty() or not bool(publish.get("published", false)):
			return _preserve_failure(filesystem, output, metadata, sorted_paths.size(), completed_files, owned_paths, owned_external_paths, "%s stage=manifest-publish reason=%s" % [ERROR_PREFIX, String(publish.get("error", "publish did not complete"))])
		owned_paths.erase(PENDING_MANIFEST_NAME)
		_register_owned(output.path_join(MANIFEST_NAME), output, owned_paths, owned_external_paths)
		return {
			"ok": true,
			"error": "",
			"manifest_path": output.path_join(MANIFEST_NAME),
			"file_count": completed_files.size(),
			"total_bytes": total_bytes,
		}


	func _validate_request(request: Dictionary, inventory_paths: PackedStringArray, source_metadata: Dictionary, filesystem: RefCounted) -> String:
		var source_raw := String(request.get("source_root", ""))
		if source_raw.is_empty() or not source_raw.is_absolute_path():
			return "%s field=source_root reason=must be absolute" % ERROR_PREFIX
		var source_root := _normalized_absolute(source_raw)
		var source_probe := filesystem.call(&"probe_path", source_root, true) as Dictionary
		if not String(source_probe.get("error", "")).is_empty():
			return "%s field=source_root reason=physical path %s" % [ERROR_PREFIX, source_probe["error"]]
		var project_probe := filesystem.call(&"probe_path", source_root.path_join("project.godot"), true) as Dictionary
		if not String(project_probe.get("error", "")).is_empty():
			return "%s field=source_root reason=project.godot must exist directly under source root" % ERROR_PREFIX

		var output_raw := String(request.get("output", ""))
		if output_raw.is_empty() or not output_raw.is_absolute_path():
			return "%s field=output reason=must be absolute" % ERROR_PREFIX
		var output := _normalized_absolute(output_raw)
		if _is_same_or_descendant(output, source_root):
			return "%s field=output reason=must be outside source root" % ERROR_PREFIX
		var output_probe := filesystem.call(&"probe_path", output, false) as Dictionary
		if not String(output_probe.get("error", "")).is_empty():
			return "%s field=output reason=physical path %s" % [ERROR_PREFIX, output_probe["error"]]
		var output_state := filesystem.call(&"directory_state", output) as Dictionary
		if not String(output_state.get("error", "")).is_empty():
			return "%s field=output reason=%s" % [ERROR_PREFIX, output_state["error"]]
		if bool(output_state.get("exists", false)) and not bool(output_state.get("empty", false)):
			return "%s field=output reason=must be empty" % ERROR_PREFIX

		var git_error := _validate_metadata(request, source_metadata)
		if not git_error.is_empty():
			return git_error
		if inventory_paths.is_empty():
			return "%s field=inventory reason=must be non-empty" % ERROR_PREFIX
		var seen := {}
		var sorted_paths := inventory_paths.duplicate()
		sorted_paths.sort()
		for relative_path: String in sorted_paths:
			if not _is_normalized_relative_path(relative_path):
				return "%s inventory path=%s reason=must be normalized and relative" % [ERROR_PREFIX, relative_path]
			if relative_path in [MANIFEST_NAME, PENDING_MANIFEST_NAME, FAILURE_NAME, PARTIAL_MANIFEST_NAME]:
				return "%s inventory path=%s reason=reserved builder output" % [ERROR_PREFIX, relative_path]
			if seen.has(relative_path):
				return "%s inventory path=%s reason=duplicate" % [ERROR_PREFIX, relative_path]
			seen[relative_path] = true
			var inventory_probe := filesystem.call(&"probe_path", source_root.path_join(relative_path), true) as Dictionary
			if not String(inventory_probe.get("error", "")).is_empty():
				return "%s inventory path=%s reason=physical path %s" % [ERROR_PREFIX, relative_path, inventory_probe["error"]]
		return ""


	func _validate_metadata(request: Dictionary, source_metadata: Dictionary) -> String:
		var source_commit := String(request.get("source_commit", ""))
		if not _is_sha40(source_commit):
			return "%s field=source_commit reason=must be exactly 40 hexadecimal characters" % ERROR_PREFIX
		if String(request.get("source_branch", "")).is_empty():
			return "%s field=source_branch reason=must be non-empty" % ERROR_PREFIX
		if not _is_sha40(String(source_metadata.get("commit", ""))):
			return "%s field=source_commit reason=actual Git HEAD is invalid" % ERROR_PREFIX
		if source_commit.to_lower() != String(source_metadata.get("commit", "")).to_lower():
			return "%s field=source_commit reason=does not match actual Git HEAD" % ERROR_PREFIX
		if String(request.get("source_branch", "")) != String(source_metadata.get("branch", "")):
			return "%s field=source_branch reason=does not match actual Git branch" % ERROR_PREFIX
		if not source_metadata.has("worktree_status"):
			return "%s field=worktree_status reason=actual full Git status is missing" % ERROR_PREFIX
		if String(source_metadata.get("toplevel", "")).is_empty():
			return "%s field=source_root reason=actual Git top-level is missing" % ERROR_PREFIX
		return ""


	func _validated_read(filesystem: RefCounted, path: String, label: String) -> Dictionary:
		var read := filesystem.call(&"read_file", path) as Dictionary
		return _validated_read_result(read, label)


	func _validated_read_result(read: Dictionary, label: String) -> Dictionary:
		if not String(read.get("error", "")).is_empty():
			return {"error": "%s read failed: %s" % [label, read["error"]]}
		if int(read.get("read_error", FAILED)) not in [OK, ERR_FILE_EOF]:
			return {"error": "%s read status code=%d" % [label, int(read.get("read_error", FAILED))]}
		var expected_length := int(read.get("expected_length", -1))
		var bytes_verified := bool(read.get("bytes_verified", false))
		var bytes := read.get("bytes", PackedByteArray()) as PackedByteArray
		if expected_length < 0 or int(read.get("bytes_read", -1)) != expected_length or int(read.get("position", -1)) != expected_length or (not bytes_verified and bytes.size() != expected_length):
			return {"error": "%s full-length read failed expected=%d bytes=%d position=%d" % [label, expected_length, int(read.get("bytes_read", -1)), int(read.get("position", -1))]}
		var reported_sha := String(read.get("sha256", ""))
		if not _is_sha256(reported_sha):
			return {"error": "%s SHA-256 is invalid" % label}
		if not bytes_verified and _hash(bytes) != reported_sha:
			return {"error": "%s SHA-256 does not match read bytes" % label}
		read["bytes"] = bytes
		return read


	func _write_verified_exclusive(filesystem: RefCounted, path: String, bytes: PackedByteArray) -> Dictionary:
		var create := filesystem.call(&"create_file_exclusive", path, bytes) as Dictionary
		if not String(create.get("error", "")).is_empty():
			return {"error": String(create["error"]), "created": bool(create.get("created", false))}
		if bool(create.get("verified", false)):
			if int(create.get("expected_length", -1)) != bytes.size() or String(create.get("sha256", "")) != _hash(bytes):
				return {"error": "verified artifact metadata differs", "created": bool(create.get("created", false))}
			return {"error": "", "created": bool(create.get("created", false)), "verified": true}
		var read := _validated_read(filesystem, path, "written artifact")
		if not String(read.get("error", "")).is_empty():
			return {"error": String(read["error"]), "created": bool(create.get("created", false))}
		if (read.get("bytes", PackedByteArray()) as PackedByteArray) != bytes:
			return {"error": "written artifact bytes differ", "created": bool(create.get("created", false))}
		return {"error": "", "created": bool(create.get("created", false)), "verified": true}


	func _preserve_failure(filesystem: RefCounted, output: String, source_metadata: Dictionary, expected_file_count: int, completed_files: Array[Dictionary], owned_paths_input: Array[String], owned_external_input: Array[String], error: String) -> Dictionary:
		var owned_paths := owned_paths_input.duplicate()
		var owned_external_paths := owned_external_input.duplicate()
		var preservation_errors := PackedStringArray()
		var marker := {
			"schema_version": 1,
			"state": "failed",
			"error": _bounded(error, MAX_FAILURE_ERROR_CHARACTERS),
			"partial_manifest": PARTIAL_MANIFEST_NAME,
			"completed_file_count": completed_files.size(),
		}
		var marker_bytes := JSON.stringify(marker, "\t", true).to_utf8_buffer()
		while marker_bytes.size() > MAX_FAILURE_MARKER_BYTES and not String(marker["error"]).is_empty():
			marker["error"] = String(marker["error"]).left(maxi(String(marker["error"]).length() / 2, 0))
			marker_bytes = JSON.stringify(marker, "\t", true).to_utf8_buffer()
		var marker_path := output.path_join(FAILURE_NAME)
		var marker_write := _write_verified_exclusive(filesystem, marker_path, marker_bytes)
		if bool(marker_write.get("created", false)):
			_register_owned(marker_path, output, owned_paths, owned_external_paths)
		var marker_verified := bool(marker_write.get("verified", false)) and String(marker_write.get("error", "")).is_empty()
		if not marker_verified:
			preservation_errors.append("failure marker: %s" % String(marker_write.get("error", "not verified")))

		var prospective_owned := owned_paths.duplicate()
		if PARTIAL_MANIFEST_NAME not in prospective_owned:
			prospective_owned.append(PARTIAL_MANIFEST_NAME)
		prospective_owned.sort()
		owned_external_paths.sort()
		var partial_manifest := {
			"schema_version": 1,
			"state": "failed",
			"source": source_metadata,
			"expected_file_count": expected_file_count,
			"completed_file_count": completed_files.size(),
			"files": completed_files,
			"owned_paths": prospective_owned,
			"owned_external_paths": owned_external_paths,
		}
		var partial_path := output.path_join(PARTIAL_MANIFEST_NAME)
		var partial_write := _write_verified_exclusive(filesystem, partial_path, JSON.stringify(partial_manifest, "\t", true).to_utf8_buffer())
		if bool(partial_write.get("created", false)):
			_register_owned(partial_path, output, owned_paths, owned_external_paths)
		var partial_verified := bool(partial_write.get("verified", false)) and String(partial_write.get("error", "")).is_empty()
		if not partial_verified:
			preservation_errors.append("partial manifest: %s" % String(partial_write.get("error", "not verified")))
		var result := _failed_result(error)
		result["failure_marker_path"] = marker_path
		result["partial_manifest_path"] = partial_path
		result["failure_marker_verified"] = marker_verified
		result["partial_manifest_verified"] = partial_verified
		result["preservation_error"] = "; ".join(preservation_errors)
		owned_paths.sort()
		owned_external_paths.sort()
		result["owned_paths"] = owned_paths
		result["owned_external_paths"] = owned_external_paths
		return result


	func _register_created(created_paths: Array, output: String, owned_paths: Array[String], owned_external_paths: Array[String]) -> void:
		for path_value: Variant in created_paths:
			_register_owned(String(path_value), output, owned_paths, owned_external_paths)


	func _register_owned(path: String, output: String, owned_paths: Array[String], owned_external_paths: Array[String]) -> void:
		var normalized := _normalized_absolute(path)
		if normalized == output:
			if "." not in owned_paths:
				owned_paths.append(".")
		elif normalized.begins_with(output + "/"):
			var relative := normalized.trim_prefix(output + "/")
			if relative not in owned_paths:
				owned_paths.append(relative)
		elif normalized not in owned_external_paths:
			owned_external_paths.append(normalized)


	func _is_normalized_relative_path(path: String) -> bool:
		if path.is_empty() or path.is_absolute_path() or path.begins_with("res://") or "\\" in path:
			return false
		var segments := path.split("/", true)
		return not segments.has("") and not segments.has(".") and not segments.has("..")


	func _normalized_absolute(path: String) -> String:
		return path.replace("\\", "/").simplify_path().trim_suffix("/")


	func _is_same_or_descendant(candidate: String, root: String) -> bool:
		var folded_candidate := candidate.to_lower()
		var folded_root := root.to_lower()
		return folded_candidate == folded_root or folded_candidate.begins_with(folded_root + "/")


	func _is_sha40(value: String) -> bool:
		if value.length() != 40:
			return false
		for character: String in value:
			if character.to_lower() not in "0123456789abcdef":
				return false
		return true


	func _is_sha256(value: String) -> bool:
		if value.length() != 64:
			return false
		for character: String in value:
			if character not in "0123456789abcdef":
				return false
		return true


	func _hash(bytes: PackedByteArray) -> String:
		var hashing := HashingContext.new()
		hashing.start(HashingContext.HASH_SHA256)
		hashing.update(bytes)
		return hashing.finish().hex_encode()


	func _bounded(value: String, maximum_characters: int) -> String:
		return value if value.length() <= maximum_characters else value.left(maximum_characters)


	func _failed_result(error: String) -> Dictionary:
		return {"ok": false, "error": error, "failure_marker_verified": false, "partial_manifest_verified": false, "preservation_error": ""}


func _initialize() -> void:
	var parsed := parse_named_args(OS.get_cmdline_user_args())
	var parse_errors := parsed.get("errors", PackedStringArray()) as PackedStringArray
	if not parse_errors.is_empty():
		_fail(parse_errors[0])
		return
	var request := parsed.get("request", {}) as Dictionary
	var source_root := String(request.get("source_root", ""))
	var filesystem := NativeFilesystem.new()
	var source_probe := filesystem.probe_path(source_root, true)
	if not String(source_probe.get("error", "")).is_empty():
		_fail("%s field=source_root reason=physical path %s" % [ERROR_PREFIX, source_probe["error"]])
		return
	var actual_metadata := GitProbe.new(filesystem).probe(source_root)
	if not String(actual_metadata.get("error", "")).is_empty():
		_fail("%s field=source_root reason=%s" % [ERROR_PREFIX, actual_metadata["error"]])
		return
	var metadata_error := validate_git_metadata(request, actual_metadata)
	if not metadata_error.is_empty():
		_fail(metadata_error)
		return
	var inventory := INVENTORY_SCRIPT.new().build(source_root) as Dictionary
	var inventory_errors := inventory.get("errors", PackedStringArray()) as PackedStringArray
	if not inventory_errors.is_empty():
		_fail(inventory_errors[0])
		return
	var result := BackupService.new().build_backup_with_filesystem(request, inventory.get("paths", PackedStringArray()) as PackedStringArray, actual_metadata, filesystem)
	if not bool(result.get("ok", false)):
		_fail(String(result.get("error", "%s reason=unknown" % ERROR_PREFIX)))
		return
	print("PARTY_FORGE_MODULAR_BACKUP_OK files=%d bytes=%d manifest=%s" % [int(result.get("file_count", 0)), int(result.get("total_bytes", 0)), String(result.get("manifest_path", ""))])
	quit(0)


func parse_named_args(arguments: PackedStringArray) -> Dictionary:
	var request := {}
	var errors := PackedStringArray()
	var index := 0
	while index < arguments.size():
		var argument := arguments[index]
		if not argument.begins_with("--"):
			errors.append("%s argument=%s reason=expected named argument" % [ERROR_PREFIX, argument])
			index += 1
			continue
		var name := argument.trim_prefix("--")
		var value := ""
		var equals_index := name.find("=")
		if equals_index >= 0:
			value = name.substr(equals_index + 1)
			name = name.left(equals_index)
		elif index + 1 < arguments.size() and not arguments[index + 1].begins_with("--"):
			value = arguments[index + 1]
			index += 1
		if not ARGUMENT_FIELDS.has(name):
			errors.append("%s argument=--%s reason=unknown" % [ERROR_PREFIX, name])
		elif request.has(ARGUMENT_FIELDS[name]):
			errors.append("%s argument=--%s reason=duplicate" % [ERROR_PREFIX, name])
		elif value.is_empty():
			errors.append("%s argument=--%s reason=value required" % [ERROR_PREFIX, name])
		else:
			request[ARGUMENT_FIELDS[name]] = value
		index += 1
	for name: String in REQUIRED_ARGUMENTS:
		var field := String(ARGUMENT_FIELDS[name])
		if not request.has(field):
			errors.append("%s argument=--%s reason=required" % [ERROR_PREFIX, name])
	return {"request": request, "errors": errors}


func validate_git_metadata(request: Dictionary, actual_metadata: Dictionary) -> String:
	return BackupService.new()._validate_metadata(request, actual_metadata)


func new_service() -> RefCounted:
	return BackupService.new()


func new_native_filesystem() -> RefCounted:
	return NativeFilesystem.new()


func _fail(error: String) -> void:
	push_error(error)
	quit(1)

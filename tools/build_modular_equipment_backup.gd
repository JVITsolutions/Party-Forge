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
	const PROBE_SCRIPT := "$ErrorActionPreference='Stop'; try { $p=[IO.Path]::GetFullPath($args[0]); $required=$args[1] -eq '1'; $root=[IO.Path]::GetPathRoot($p); $current=$root; $relative=$p.Substring($root.Length); foreach($segment in $relative.Split([IO.Path]::DirectorySeparatorChar,[StringSplitOptions]::RemoveEmptyEntries)) { $current=[IO.Path]::Combine($current,$segment); if([IO.File]::Exists($current) -or [IO.Directory]::Exists($current)) { $item=Get-Item -LiteralPath $current -Force; if(($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { [Console]::Out.Write('reparse component: '+$current); exit 42 } } else { if($required) { [Console]::Out.Write('path does not exist: '+$current); exit 43 }; break } }; [Console]::Out.Write($p) } catch { [Console]::Out.Write($_.Exception.Message); exit 44 }"
	const CREATE_DIRECTORY_SCRIPT := "$ErrorActionPreference='Stop'; Add-Type -TypeDefinition 'using System; using System.Runtime.InteropServices; public static class Task3DirectoryNative { [DllImport(\"kernel32.dll\", CharSet=CharSet.Unicode, SetLastError=true)] public static extern bool CreateDirectory(string path, IntPtr attributes); }'; function Assert-Safe([string]$path,[string]$anchor) { $p=[IO.Path]::GetFullPath($path); $a=[IO.Path]::GetFullPath($anchor).TrimEnd([IO.Path]::DirectorySeparatorChar); $prefix=$a+[IO.Path]::DirectorySeparatorChar; if(-not ($p.Equals($a,[StringComparison]::OrdinalIgnoreCase) -or $p.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase))) { throw 'containment failure' }; $root=[IO.Path]::GetPathRoot($p); $current=$root; foreach($segment in $p.Substring($root.Length).Split([IO.Path]::DirectorySeparatorChar,[StringSplitOptions]::RemoveEmptyEntries)) { $current=[IO.Path]::Combine($current,$segment); if([IO.File]::Exists($current) -or [IO.Directory]::Exists($current)) { $item=Get-Item -LiteralPath $current -Force; if(($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw ('reparse component: '+$current) } } else { break } }; return $p }; $created=$false; try { $p=Assert-Safe ($args[0]) ($args[1]); $parent=Assert-Safe ([IO.Path]::GetDirectoryName($p)) ($args[1]); if(-not [IO.Directory]::Exists($parent)) { throw 'parent missing' }; if(-not [Task3DirectoryNative]::CreateDirectory($p,[IntPtr]::Zero)) { throw ('CreateDirectoryW failed code='+[Runtime.InteropServices.Marshal]::GetLastWin32Error()) }; $created=$true; $item=Get-Item -LiteralPath $p -Force; if(($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'created directory became reparse point' }; [Console]::Out.Write('created=1'); exit 0 } catch { $flag=if($created){'1'}else{'0'}; [Console]::Out.Write('created='+$flag+';'+$_.Exception.Message); exit 45 }"
	const CREATE_SCRIPT := "$ErrorActionPreference='Stop'; function Assert-Safe([string]$path,[string]$anchor) { $p=[IO.Path]::GetFullPath($path); $a=[IO.Path]::GetFullPath($anchor).TrimEnd([IO.Path]::DirectorySeparatorChar); $prefix=$a+[IO.Path]::DirectorySeparatorChar; if(-not ($p.Equals($a,[StringComparison]::OrdinalIgnoreCase) -or $p.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase))) { throw 'containment failure' }; $root=[IO.Path]::GetPathRoot($p); $current=$root; foreach($segment in $p.Substring($root.Length).Split([IO.Path]::DirectorySeparatorChar,[StringSplitOptions]::RemoveEmptyEntries)) { $current=[IO.Path]::Combine($current,$segment); if([IO.File]::Exists($current) -or [IO.Directory]::Exists($current)) { $item=Get-Item -LiteralPath $current -Force; if(($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw ('reparse component: '+$current) } } else { break } }; return $p }; $created=$false; $stream=$null; try { $p=Assert-Safe ($args[0]) ($args[1]); $parent=Assert-Safe ([IO.Path]::GetDirectoryName($p)) ($args[1]); if(-not [IO.Directory]::Exists($parent)) { throw 'parent missing' }; $expected=[long]::Parse($args[2],[Globalization.CultureInfo]::InvariantCulture); $expectedHash=$args[3]; $stream=[IO.File]::Open($p,[IO.FileMode]::CreateNew,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None); $created=$true; while($true) { $line=[Console]::In.ReadLine(); if($null -eq $line) { throw 'content channel closed' }; if($line -eq '.') { break }; $chunk=[Convert]::FromBase64String($line); $stream.Write($chunk,0,$chunk.Length) }; $stream.Flush($true); if($stream.Length -ne $expected) { throw 'short write' }; $stream.Position=0; $sha=[Security.Cryptography.SHA256]::Create(); try { $actualHash=([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-','').ToLowerInvariant() } finally { $sha.Dispose() }; if($actualHash -ne $expectedHash) { throw 'write hash mismatch' }; $stream.Dispose(); $stream=$null; [Console]::Out.Write('created=1'); exit 0 } catch { if($null -ne $stream) { $stream.Dispose() }; $flag=if($created){'1'}else{'0'}; [Console]::Out.Write('created='+$flag+';'+$_.Exception.Message); exit 46 }"
	const PUBLISH_SCRIPT := "$ErrorActionPreference='Stop'; function Assert-Safe([string]$path,[string]$anchor) { $p=[IO.Path]::GetFullPath($path); $a=[IO.Path]::GetFullPath($anchor).TrimEnd([IO.Path]::DirectorySeparatorChar); $prefix=$a+[IO.Path]::DirectorySeparatorChar; if(-not ($p.Equals($a,[StringComparison]::OrdinalIgnoreCase) -or $p.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase))) { throw 'containment failure' }; $root=[IO.Path]::GetPathRoot($p); $current=$root; foreach($segment in $p.Substring($root.Length).Split([IO.Path]::DirectorySeparatorChar,[StringSplitOptions]::RemoveEmptyEntries)) { $current=[IO.Path]::Combine($current,$segment); if([IO.File]::Exists($current) -or [IO.Directory]::Exists($current)) { $item=Get-Item -LiteralPath $current -Force; if(($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw ('reparse component: '+$current) } } else { break } }; return $p }; try { $pending=Assert-Safe ($args[0]) ($args[2]); $final=Assert-Safe ($args[1]) ($args[2]); if(-not [IO.File]::Exists($pending)) { throw 'pending missing' }; if([IO.File]::Exists($final) -or [IO.Directory]::Exists($final)) { throw 'collision' }; [IO.File]::Move($pending,$final); exit 0 } catch { [Console]::Out.Write($_.Exception.Message); exit 47 }"
	var _mutation_anchor := ""


	func probe_path(path: String, require_exists: bool) -> Dictionary:
		var result := _run_powershell(PROBE_SCRIPT, [path, "1" if require_exists else "0"])
		if int(result.get("exit_code", -1)) != 0:
			return {"error": "physical path probe failed code=%d detail=%s" % [int(result.get("exit_code", -1)), _bounded_output(String(result.get("output", "")))], "path": ""}
		return {"error": "", "path": String(result.get("output", "")).strip_edges().replace("\\", "/")}


	func directory_state(path: String) -> Dictionary:
		if FileAccess.file_exists(path):
			return {"error": "path is a file", "exists": false, "empty": false}
		if not DirAccess.dir_exists_absolute(path):
			return {"error": "", "exists": false, "empty": true}
		return {
			"error": "",
			"exists": true,
			"empty": DirAccess.get_files_at(path).is_empty() and DirAccess.get_directories_at(path).is_empty(),
		}


	func configure_output_root(path: String) -> Dictionary:
		var cursor := path.replace("\\", "/").simplify_path().trim_suffix("/")
		while not DirAccess.dir_exists_absolute(cursor):
			if FileAccess.file_exists(cursor):
				return {"error": "output ancestor is a file: %s" % cursor}
			var parent := cursor.get_base_dir()
			if parent == cursor:
				return {"error": "cannot resolve existing output ancestor"}
			cursor = parent
		var probe := probe_path(cursor, true)
		if not String(probe.get("error", "")).is_empty():
			return {"error": String(probe["error"])}
		_mutation_anchor = String(probe.get("path", ""))
		return {"error": ""}


	func ensure_directory(path: String) -> Dictionary:
		if _mutation_anchor.is_empty():
			return {"error": "output containment root was not configured", "created_paths": []}
		var normalized := path.replace("\\", "/").simplify_path().trim_suffix("/")
		var missing: Array[String] = []
		var cursor := normalized
		while not cursor.is_empty() and not DirAccess.dir_exists_absolute(cursor):
			if FileAccess.file_exists(cursor):
				return {"error": "directory component is a file: %s" % cursor, "created_paths": []}
			missing.append(cursor)
			var parent := cursor.get_base_dir()
			if parent == cursor:
				break
			cursor = parent
		missing.reverse()
		var created: Array[String] = []
		for directory: String in missing:
			var parent_probe := probe_path(directory.get_base_dir(), true)
			if not String(parent_probe.get("error", "")).is_empty():
				return {"error": String(parent_probe["error"]), "created_paths": created}
			var create_result := _run_powershell(CREATE_DIRECTORY_SCRIPT, [directory, _mutation_anchor])
			var helper_output := String(create_result.get("output", ""))
			var helper_created := helper_output.begins_with("created=1")
			if helper_created:
				created.append(directory)
			if int(create_result.get("exit_code", -1)) != 0:
				return {"error": "directory exclusive create failed code=%d detail=%s" % [int(create_result.get("exit_code", -1)), _bounded_output(helper_output)], "created_paths": created}
			if not helper_created:
				return {"error": "directory exclusive create returned invalid helper status", "created_paths": created}
			var created_probe := probe_path(directory, true)
			if not String(created_probe.get("error", "")).is_empty():
				return {"error": String(created_probe["error"]), "created_paths": created}
			if not DirAccess.dir_exists_absolute(directory):
				return {"error": "created path is not a directory: %s" % directory, "created_paths": created}
		return {"error": "", "created_paths": created}


	func read_file(path: String) -> Dictionary:
		var probe := probe_path(path, true)
		if not String(probe.get("error", "")).is_empty():
			return {"error": String(probe["error"]), "bytes": PackedByteArray(), "expected_length": -1, "bytes_read": 0, "position": 0, "read_error": ERR_FILE_CANT_READ, "sha256": ""}
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			return {"error": "cannot open", "bytes": PackedByteArray(), "expected_length": -1, "bytes_read": 0, "position": 0, "read_error": ERR_CANT_OPEN, "sha256": ""}
		var expected_length := file.get_length()
		var bytes := file.get_buffer(expected_length)
		var position := file.get_position()
		var read_error := file.get_error()
		file.close()
		return {"error": "", "bytes": bytes, "expected_length": expected_length, "bytes_read": bytes.size(), "position": position, "read_error": read_error, "sha256": _hash(bytes)}


	func create_file_exclusive(path: String, bytes: PackedByteArray) -> Dictionary:
		if _mutation_anchor.is_empty():
			return {"error": "output containment root was not configured", "created": false}
		var parent_probe := probe_path(path.get_base_dir(), true)
		if not String(parent_probe.get("error", "")).is_empty():
			return {"error": String(parent_probe["error"]), "created": false}
		var create_result := _run_powershell_with_input(CREATE_SCRIPT, [path, _mutation_anchor, str(bytes.size()), _hash(bytes)], bytes)
		var helper_output := String(create_result.get("output", ""))
		var created := helper_output.begins_with("created=1")
		if int(create_result.get("exit_code", -1)) != 0:
			return {"error": "exclusive create failed code=%d detail=%s" % [int(create_result.get("exit_code", -1)), _bounded_output(helper_output)], "created": created}
		if not created:
			return {"error": "exclusive create returned invalid helper status", "created": false}
		var created_probe := probe_path(path, true)
		if not String(created_probe.get("error", "")).is_empty():
			return {"error": String(created_probe["error"]), "created": true}
		return {"error": "", "created": true}


	func publish_no_replace(pending_path: String, final_path: String) -> Dictionary:
		if _mutation_anchor.is_empty():
			return {"error": "output containment root was not configured", "published": false}
		var pending_probe := probe_path(pending_path, true)
		if not String(pending_probe.get("error", "")).is_empty():
			return {"error": String(pending_probe["error"]), "published": false}
		var parent_probe := probe_path(final_path.get_base_dir(), true)
		if not String(parent_probe.get("error", "")).is_empty():
			return {"error": String(parent_probe["error"]), "published": false}
		var publish_result := _run_powershell(PUBLISH_SCRIPT, [pending_path, final_path, _mutation_anchor])
		if int(publish_result.get("exit_code", -1)) != 0:
			return {"error": "atomic no-replace publish failed code=%d detail=%s" % [int(publish_result.get("exit_code", -1)), _bounded_output(String(publish_result.get("output", "")))], "published": false}
		return {"error": "", "published": true}


	func _run_powershell(script: String, arguments: Array[String]) -> Dictionary:
		var output: Array = []
		var process_arguments := PackedStringArray(["-NoLogo", "-NoProfile", "-NonInteractive"])
		process_arguments.append_array(encoded_invocation(script, PackedStringArray(arguments)))
		var exit_code := OS.execute("powershell.exe", process_arguments, output, false)
		return {"exit_code": exit_code, "output": "".join(output)}


	func _run_powershell_with_input(script: String, arguments: Array[String], bytes: PackedByteArray) -> Dictionary:
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
			return {"exit_code": -1, "output": "helper pipe creation failed"}
		var deadline := Time.get_ticks_msec() + 300000
		var content_line := bytes
		var offset := 0
		while offset < content_line.size():
			var next_offset := mini(offset + 2048, content_line.size())
			var encoded_chunk := Marshalls.raw_to_base64(content_line.slice(offset, next_offset)) + "\n"
			while not stdio.store_string(encoded_chunk):
				if not OS.is_process_running(pid) or Time.get_ticks_msec() >= deadline:
					OS.kill(pid)
					stdio.close()
					if stderr != null:
						stderr.close()
					return {"exit_code": -1, "output": "helper content channel write failed"}
				OS.delay_msec(1)
			offset = next_offset
		while not stdio.store_string(".\n"):
			if not OS.is_process_running(pid) or Time.get_ticks_msec() >= deadline:
				OS.kill(pid)
				stdio.close()
				if stderr != null:
					stderr.close()
				return {"exit_code": -1, "output": "helper content terminator write failed"}
			OS.delay_msec(1)
		while OS.is_process_running(pid) and Time.get_ticks_msec() < deadline:
			OS.delay_msec(5)
		if OS.is_process_running(pid):
			OS.kill(pid)
			stdio.close()
			if stderr != null:
				stderr.close()
			return {"exit_code": -1, "output": "helper timed out"}
		var exit_code := OS.get_process_exit_code(pid)
		var output := stdio.get_as_text()
		stdio.close()
		if stderr != null:
			stderr.close()
		return {"exit_code": exit_code, "output": output}


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
		return {
			"error": "",
			"commit": String(head.get("output", "")).strip_edges(),
			"branch": String(branch.get("output", "")).strip_edges(),
			"worktree_status": String(status.get("output", "")),
		}


	func _git(source_root: String, arguments: Array[String]) -> Dictionary:
		var output: Array = []
		var git_arguments := PackedStringArray(["-C", source_root])
		git_arguments.append_array(PackedStringArray(arguments))
		var exit_code := OS.execute("git", git_arguments, output, true)
		return {"exit_code": exit_code, "output": "".join(output)}


class BackupService extends RefCounted:
	func build_backup_with_filesystem(request: Dictionary, inventory_paths: PackedStringArray, source_metadata: Dictionary, filesystem: RefCounted) -> Dictionary:
		if filesystem == null:
			return _failed_result("%s field=filesystem reason=race-safe adapter required" % ERROR_PREFIX)
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
		}
		var owned_paths: Array[String] = []
		var owned_external_paths: Array[String] = []
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
			var source_read := _validated_read(filesystem, source_path, "source")
			if not String(source_read.get("error", "")).is_empty():
				return _preserve_failure(filesystem, output, metadata, sorted_paths.size(), completed_files, owned_paths, owned_external_paths, "%s stage=copy path=%s reason=%s" % [ERROR_PREFIX, relative_path, source_read["error"]])
			var source_bytes := source_read.get("bytes", PackedByteArray()) as PackedByteArray
			var create_result := filesystem.call(&"create_file_exclusive", destination_path, source_bytes) as Dictionary
			if bool(create_result.get("created", false)):
				_register_owned(destination_path, output, owned_paths, owned_external_paths)
			if not String(create_result.get("error", "")).is_empty():
				return _preserve_failure(filesystem, output, metadata, sorted_paths.size(), completed_files, owned_paths, owned_external_paths, "%s stage=copy path=%s reason=%s" % [ERROR_PREFIX, relative_path, create_result["error"]])
			var destination_read := _validated_read(filesystem, destination_path, "destination")
			if not String(destination_read.get("error", "")).is_empty():
				return _preserve_failure(filesystem, output, metadata, sorted_paths.size(), completed_files, owned_paths, owned_external_paths, "%s stage=verify path=%s reason=%s" % [ERROR_PREFIX, relative_path, destination_read["error"]])
			if String(source_read.get("sha256", "")) != String(destination_read.get("sha256", "")) or source_bytes != (destination_read.get("bytes", PackedByteArray()) as PackedByteArray):
				return _preserve_failure(filesystem, output, metadata, sorted_paths.size(), completed_files, owned_paths, owned_external_paths, "%s stage=verify path=%s reason=source and destination hash mismatch" % [ERROR_PREFIX, relative_path])
			var row := {
				"path": relative_path,
				"size": source_bytes.size(),
				"sha256": String(destination_read.get("sha256", "")),
			}
			completed_files.append(row)
			total_bytes += source_bytes.size()

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
		if not String(project_probe.get("error", "")).is_empty() or not FileAccess.file_exists(source_root.path_join("project.godot")):
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
		return ""


	func _validated_read(filesystem: RefCounted, path: String, label: String) -> Dictionary:
		var read := filesystem.call(&"read_file", path) as Dictionary
		if not String(read.get("error", "")).is_empty():
			return {"error": "%s read failed: %s" % [label, read["error"]]}
		if int(read.get("read_error", FAILED)) not in [OK, ERR_FILE_EOF]:
			return {"error": "%s read status code=%d" % [label, int(read.get("read_error", FAILED))]}
		var expected_length := int(read.get("expected_length", -1))
		var bytes := read.get("bytes", PackedByteArray()) as PackedByteArray
		if expected_length < 0 or int(read.get("bytes_read", -1)) != expected_length or int(read.get("position", -1)) != expected_length or bytes.size() != expected_length:
			return {"error": "%s full-length read failed expected=%d bytes=%d position=%d" % [label, expected_length, bytes.size(), int(read.get("position", -1))]}
		var reported_sha := String(read.get("sha256", ""))
		if not _is_sha256(reported_sha):
			return {"error": "%s SHA-256 is invalid" % label}
		if _hash(bytes) != reported_sha:
			return {"error": "%s SHA-256 does not match read bytes" % label}
		read["bytes"] = bytes
		return read


	func _write_verified_exclusive(filesystem: RefCounted, path: String, bytes: PackedByteArray) -> Dictionary:
		var create := filesystem.call(&"create_file_exclusive", path, bytes) as Dictionary
		if not String(create.get("error", "")).is_empty():
			return {"error": String(create["error"]), "created": bool(create.get("created", false))}
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
	var actual_metadata := GitProbe.new().probe(source_root)
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

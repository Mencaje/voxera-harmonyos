import { fileIo as fs } from '@kit.CoreFileKit';

/** Runs on taskpool thread — must not block the UI main thread. writeMigrateMarker: 1 = write .migrated_from_sandbox */
@Concurrent
export function userDataCopyTask(engineDir: string, publicRoot: string, writeMigrateMarker: number): void {
  if (!engineDir || !publicRoot || engineDir === publicRoot) {
    return;
  }
  try {
    fs.accessSync(engineDir);
  } catch {
    return;
  }
  const subs: string[] = [
    'worlds', 'games', 'mods', 'clientmods', 'textures', 'client/serverlist',
  ];
  try {
    fs.mkdirSync(publicRoot, true);
  } catch {
    // ignore
  }
  for (let s = 0; s < subs.length; s++) {
    const rel = subs[s];
    const idx = rel.indexOf('/');
    if (idx >= 0) {
      try {
        fs.mkdirSync(`${publicRoot}/${rel.substring(0, idx)}`, true);
      } catch {
        // ignore
      }
    }
    try {
      fs.mkdirSync(`${publicRoot}/${rel}`, true);
    } catch {
      // ignore
    }
  }
  let names: string[] = [];
  try {
    names = fs.listFileSync(engineDir);
  } catch {
    return;
  }
  const copyTree = (src: string, dest: string): void => {
    let entries: string[] = [];
    try {
      entries = fs.listFileSync(src);
    } catch {
      return;
    }
    try {
      fs.mkdirSync(dest, true);
    } catch {
      // ignore
    }
    for (let i = 0; i < entries.length; i++) {
      const name = entries[i];
      if (name === '.' || name === '..') {
        continue;
      }
      const from = `${src}/${name}`;
      const to = `${dest}/${name}`;
      let isDir = false;
      try {
        isDir = fs.statSync(from).isDirectory();
      } catch {
        continue;
      }
      if (isDir) {
        copyTree(from, to);
      } else {
        try {
          try {
            fs.unlinkSync(to);
          } catch {
            // ignore
          }
          fs.copyFileSync(from, to);
        } catch {
          // ignore
        }
      }
    }
  };
  copyTree(engineDir, publicRoot);
  if (writeMigrateMarker !== 0) {
    const marker = `${publicRoot}/.migrated_from_sandbox`;
    const flag = fs.openSync(marker, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
    fs.writeSync(flag.fd, new Date().toISOString());
    fs.closeSync(flag);
  }
}

import ../File, os/Time, structs/ArrayList

include dirent

/*
 * Directory covers
 */

DIR: extern cover

DirEnt: cover from struct dirent {
    name: extern(d_name) Char*
    /* TODO: the struct has more members, actually */
}

closedir: extern func (DIR*) -> Int
opendir: extern func (const Char*) -> DIR*
readdir: extern func (DIR*) -> DirEnt*
readdir_r: extern func (DIR*, DirEnt*, DirEnt**) -> Int
rewinddir: extern func (DIR*)
seekdir: extern func (DIR*, Long)
telldir: extern func (DIR*) -> Long

realpath: extern func(path: Char*, resolved: Char*) -> Char*

version(linux) {
    include unistd | (__USE_BSD), sys/stat | (__USE_BSD), sys/types | (__USE_BSD), stdlib | (__USE_BSD), limits
}
version(!linux) {
    include unistd, sys/stat, sys/types, stdlib
}

version(unix || apple) {

    // separators
    File separator = '/'
    File pathDelimiter = ':'

    _getcwd: extern (getcwd) func(buf: Char*, size: SizeT) -> Char*

    ModeT: cover from mode_t

    FileStat: cover from struct stat {
        st_mode: extern ModeT
        st_size: extern SizeT
        st_atime, st_mtime, st_ctime: extern TimeT
    }

    S_ISDIR: extern func(...) -> Bool
    S_ISREG: extern func(...) -> Bool
    S_ISLNK: extern func(...) -> Bool
    S_IRWXU, S_IRWXG, S_IRWXO: extern Int // constants

    lstat: extern func(Char*, FileStat*) -> Int
    _mkdir: extern(mkdir) func(Char*, ModeT) -> Int
    remove: extern func(path: Char*) -> Int
    _remove: unmangled func(path: String) -> Int {
        remove(path)
    }

    /*
     * Unix (POSIX) implementation of File
     */
    FileUnix: class extends File {

        init: func ~unix (=path) {}

        /**
         * @return true if it's a directory
         */
        dir?: func -> Bool {
            stat: FileStat
            lstat(path, stat&)
            return S_ISDIR(stat st_mode)
        }

        /**
         * @return true if it's a file (ie. not a directory nor a symbolic link)
         */
        file?: func -> Bool {
            stat: FileStat
            lstat(path, stat&)
            return S_ISREG(stat st_mode)
        }

        /**
         * @return true if the file is a symbolic link
         */
        link?: func -> Bool {
            stat: FileStat
            lstat(path, stat&)
            return S_ISLNK(stat st_mode)
        }

        /**
         * @return the size of the file, in bytes
         */
        size: func -> LLong {
            stat: FileStat
            lstat(path, stat&)
            return stat st_size as LLong
        }

        /**
         * @return the permissions for the owner of this file
         */
        ownerPerm: func -> Int {
            stat: FileStat
            lstat(path, stat&)
            return ((stat st_mode) & S_IRWXU) as Int >> 6
        }

        /**
         * @return the permissions for the group of this file
         */
        groupPerm: func -> Int {
            stat: FileStat
            lstat(path, stat&)
            return ((stat st_mode) & S_IRWXG) as Int >> 3
        }

        /**
         * @return the permissions for the others (not owner, not group)
         */
        otherPerm: func -> Int {
            stat: FileStat
            lstat(path, stat&)
            return ((stat st_mode) & S_IRWXO) as Int
        }

        /**
         * @return the time of last access, or -1 if it doesn't exist
         */
        lastAccessed: func -> Long {
            if(!exists?()) return -1
            stat: FileStat
            lstat(path, stat&)
            return stat st_atime as Long
        }

        /**
         * @return the time of last modification, or -1 if it doesn't exist
         */
        lastModified: func -> Long {
            if(!exists?()) return -1
            stat: FileStat
            lstat(path, stat&)
            return stat st_mtime as Long
        }

        /**
         * @return the time of creation, or -1 if it doesn't exist
         */
        created: func -> Long {
            if(!exists?()) return -1
            stat: FileStat
            lstat(path, stat&)
            return stat st_ctime as Long
        }

        /**
         * @return true if the function is relative to the current directory
         */
        relative?: func -> Bool {
            // that's a bit rough, but should work most of the time
            path startsWith?(".") || !path startsWith?("/")
        }

        /**
         * The absolute path, e.g. "my/dir" => "/current/directory/my/dir"
         */
        getAbsolutePath: func -> String {
            actualPath := String new(This MAX_PATH_LENGTH + 1)
            return realpath(path, actualPath)
        }

        /**
         * A file corresponding to the absolute path
         * @see getAbsolutePath
         */
        getAbsoluteFile: func -> File {
            actualPath := getAbsolutePath()
            if(!path equals?(actualPath)) {
                return File new(actualPath)
            }
            return this
        }

        getChildrenNames: func -> ArrayList<String> {
            if(!dir?()) {
                Exception new(This, "Trying to get the children of the non-directory '" + path + "'!") throw()
            }
            dir := opendir(path)
            if(!dir) {
                Exception new(This, "Couldn't open directory '" + path + "' for reading!") throw()
            }
            result := ArrayList<String> new()
            entry := readdir(dir)
            while(entry != null) {
                if(!entry@ name equals?(".") && !entry@ name equals?("..")) {
                    result add(entry@ name clone())
                }
                entry = readdir(dir)
            }
            closedir(dir)
            return result
        }

        getChildren: func -> ArrayList<File> {
            if(!dir?()) {
                Exception new(This, "Trying to get the children of the non-directory '" + path + "'!") throw()
            }
            dir := opendir(path)
            if(!dir) {
                Exception new(This, "Couldn't open directory '" + path + "' for reading!") throw()
            }
            result := ArrayList<File> new()
            entry := readdir(dir)
            while(entry != null) {
                if(!entry@ name equals?(".") && !entry@ name equals?("..")) {
                    result add(File new(this, entry@ name clone()))
                }
                entry = readdir(dir)
            }
            closedir(dir)
            return result
        }

        mkdir: func ~withMode (mode: Int32) -> Int {
            _mkdir(path, mode as ModeT)
        }

    }

}

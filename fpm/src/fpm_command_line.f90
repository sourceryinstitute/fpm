module fpm_command_line
use fpm_environment,  only : get_os_type, &
                             OS_UNKNOWN, OS_LINUX, OS_MACOS, OS_WINDOWS, &
                             OS_CYGWIN, OS_SOLARIS, OS_FREEBSD
use M_CLI2,           only : set_args, lget, unnamed, remaining, specified
use fpm_strings,      only : lower
use fpm_filesystem,   only : basename, canon_path
use,intrinsic :: iso_fortran_env, only : stdin=>input_unit, &
                                       & stdout=>output_unit, &
                                       & stderr=>error_unit
implicit none

private
public :: fpm_cmd_settings, &
          fpm_build_settings, &
          fpm_install_settings, &
          fpm_new_settings, &
          fpm_run_settings, &
          fpm_test_settings, &
          get_command_line_settings

type, abstract :: fpm_cmd_settings
end type

integer,parameter :: ibug=4096
type, extends(fpm_cmd_settings)  :: fpm_new_settings
    character(len=:),allocatable :: name
    logical                      :: with_executable=.false.
    logical                      :: with_test=.false.
    logical                      :: with_lib=.true.
    logical                      :: backfill=.true.
end type

type, extends(fpm_cmd_settings)  :: fpm_build_settings
    logical                      :: release=.false.
    logical                      :: list=.false.
end type

type, extends(fpm_cmd_settings)  :: fpm_run_settings
    character(len=ibug),allocatable :: name(:)
    logical                      :: release=.false.
    logical                      :: list=.false.
    character(len=:),allocatable :: args
end type

type, extends(fpm_cmd_settings)  :: fpm_test_settings
    character(len=ibug),allocatable :: name(:)
    logical                      :: release=.false.
    logical                      :: list=.false.
    character(len=:),allocatable :: args
end type

type, extends(fpm_cmd_settings)  :: fpm_install_settings
end type

character(len=:),allocatable :: name
character(len=:),allocatable :: os_type
character(len=ibug),allocatable :: names(:)

character(len=:), allocatable :: version_text(:)
character(len=:), allocatable :: help_new(:), help_fpm(:), help_run(:), &
                 & help_test(:), help_build(:), help_usage(:), &
                 & help_text(:), help_install(:), help_help(:), &
                 & help_list(:), help_list_dash(:), help_list_nodash(:)

contains
    subroutine get_command_line_settings(cmd_settings)
        class(fpm_cmd_settings), allocatable, intent(out) :: cmd_settings

        character(len=4096)           :: cmdarg
        integer                       :: i
        integer                       :: widest

        call set_help()
        ! text for --version switch,
        select case (get_os_type())
            case (OS_LINUX);   os_type =  "OS Type:     Linux"
            case (OS_MACOS);   os_type =  "OS Type:     macOS"
            case (OS_WINDOWS); os_type =  "OS Type:     Windows"
            case (OS_CYGWIN);  os_type =  "OS Type:     Cygwin"
            case (OS_SOLARIS); os_type =  "OS Type:     Solaris"
            case (OS_FREEBSD); os_type =  "OS Type:     FreeBSD"
            case (OS_UNKNOWN); os_type =  "OS Type:     Unknown"
            case default     ; os_type =  "OS Type:     UNKNOWN"
        end select
        version_text = [character(len=80) :: &
         &  'Version:     0.1.0, Pre-alpha',                           &
         &  'Program:     fpm(1)',                                     &
         &  'Description: A Fortran package manager and build system', &
         &  'Home Page:   https://github.com/fortran-lang/fpm',        &
         &  'License:     MIT',                                        &
         &  os_type]
        ! find the subcommand name by looking for first word on command
        ! not starting with dash
        cmdarg = ''
        do i = 1, command_argument_count()
            call get_command_argument(i, cmdarg)
            if(adjustl(cmdarg(1:1)) .ne. '-')exit
        enddo

        ! now set subcommand-specific help text and process commandline
        ! arguments. Then call subcommand routine
        select case(trim(cmdarg))

        case('run')
            call set_args('--list F --release F --',help_run,version_text)

            if( size(unnamed) .gt. 1 )then
                names=unnamed(2:)
            else
                names=[character(len=len(names)) :: ]
            endif

            allocate(fpm_run_settings :: cmd_settings)
            cmd_settings=fpm_run_settings( name=names, list=lget('list'), &
            & release=lget('release'), args=remaining )

        case('build')
            call set_args( '--release F --list F --',help_build,version_text )

            allocate( fpm_build_settings :: cmd_settings )
            cmd_settings=fpm_build_settings( release=lget('release'), &
                                             & list=lget('list') )

        case('new')
            call set_args(' --src F --lib F --app F --test F --backfill F', &
            & help_new, version_text)
            select case(size(unnamed))
            case(1)
                write(stderr,'(*(g0,/))')'ERROR: directory name required'
                write(stderr,'(*(7x,g0,/))') &
                & 'USAGE: fpm new NAME [--lib|--src] [--app] [--test] [--backfill]'
                stop 1
            case(2)
                name=trim(unnamed(2))
            case default
                write(stderr,'(g0)')'ERROR: only one directory name allowed'
                write(stderr,'(7x,g0)') &
                & 'USAGE: fpm new NAME [--lib|--src] [--app] [--test] [--backfill]'
                stop 2
            end select
            !*! canon_path is not converting ".", etc.
            name=canon_path(name)
            if( .not.is_fortran_name(basename(name)) )then
                write(stderr,'(g0)') [ character(len=72) :: &
                & 'ERROR: the new directory basename must be an allowed ', &
                & '       Fortran name. It must be composed of 1 to 63 ASCII', &
                & '       characters and start with a letter and be composed', &
                & '       entirely of alphanumeric characters [a-zA-Z0-9]', &
                & '       and underscores.']
                stop 4
            endif

            allocate(fpm_new_settings :: cmd_settings)

            if (any( specified(['src ','lib ','app ','test']) ) )then
                cmd_settings=fpm_new_settings(name=name,    &
                 & with_executable=lget('app'),             &
                 & with_test=lget('test'),                  &
                 & with_lib=any([lget('lib'),lget('src')]), &
                 & backfill=lget('backfill') )
            else
                cmd_settings=fpm_new_settings(name=name, &
                 & with_executable=.true.,               &
                 & with_test=.true.,                     &
                 & with_lib=.true.,                      &
                 & backfill=lget('backfill') )
            endif

        case('help')
            call set_args(' ',help_help,version_text)
            if(size(unnamed).lt.2)then
                unnamed=['help', 'fpm ']
            endif
            widest=256
            allocate(character(len=widest) :: help_text(0))
            do i=2,size(unnamed)
                select case(unnamed(i))
                case('build  ' )
                   help_text=[character(len=widest) :: help_text, help_build]
                case('run    ' )
                   help_text=[character(len=widest) :: help_text, help_run]
                case('help   ' )
                   help_text=[character(len=widest) :: help_text, help_help]
                case('test   ' )
                   help_text=[character(len=widest) :: help_text, help_test]
                case('new    ' )
                   help_text=[character(len=widest) :: help_text, help_new]
                case('fpm    ' )
                   help_text=[character(len=widest) :: help_text, help_fpm]
                case('list   ' )
                   help_text=[character(len=widest) :: help_text, help_list]
                case('version' )
                   help_text=[character(len=widest) :: help_text, version_text]
                case('manual ' )
                   help_text=[character(len=widest) :: help_text, help_fpm]
                   help_text=[character(len=widest) :: help_text, help_new]
                   help_text=[character(len=widest) :: help_text, help_build]
                   help_text=[character(len=widest) :: help_text, help_run]
                   help_text=[character(len=widest) :: help_text, help_test]
                   help_text=[character(len=widest) :: help_text, help_help]
                   help_text=[character(len=widest) :: help_text, help_list]
                   help_text=[character(len=widest) :: help_text, version_text]
                case default
                   help_text=[character(len=widest) :: help_text, &
                   & 'ERROR: unknown help topic "'//trim(unnamed(i))//'"']
                end select
            enddo
            call printhelp(help_text)

        case('install')
            call set_args('--release F ', help_install, version_text)

            allocate(fpm_install_settings :: cmd_settings)
        case('list')
            call set_args(' --list F', help_list, version_text)
            call printhelp(help_list_nodash)
            if(lget('list'))then
               call printhelp(help_list_dash)
            endif
        case('test')
            call set_args('--list F --release F --',help_test,version_text)

            if( size(unnamed) .gt. 1 )then
                names=unnamed(2:)
            else
                names=[character(len=len(names)) :: ]
            endif

            allocate(fpm_test_settings :: cmd_settings)
            cmd_settings=fpm_test_settings( name=names, list=lget('list'), &
            & release=lget('release'), args=remaining )

        case default

            call set_args(' --list F', help_fpm, version_text)
            ! Note: will not get here if --version or --usage or --help
            ! is present on commandline
            help_text=help_usage
            if(lget('list'))then
               help_text=help_list_dash
            elseif(len_trim(cmdarg).eq.0)then
                write(stdout,'(*(a))')'Fortran Package Manager:'
                write(stdout,'(*(a))')' '
                call printhelp(help_list_nodash)
            else
                write(stderr,'(*(a))')'ERROR: unknown subcommand [', &
                 & trim(cmdarg), ']'
                call printhelp(help_list_dash)
            endif
            call printhelp(help_text)

        end select
    contains
    subroutine printhelp(lines)
    character(len=:),intent(in),allocatable :: lines(:)
            write(stdout,'(g0)')(trim(lines(i)), i=1, size(lines) )
    end subroutine printhelp
    end subroutine get_command_line_settings

    function is_fortran_name(line) result (lout)
    ! determine if a string is a valid Fortran name ignoring trailing spaces
    ! (but not leading spaces)
    character(len=*),parameter   :: int='0123456789'
    character(len=*),parameter   :: lower='abcdefghijklmnopqrstuvwxyz'
    character(len=*),parameter   :: upper='ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    character(len=*),parameter   :: allowed=upper//lower//int//'_'
    character(len=*),intent(in)  :: line
    character(len=:),allocatable :: name
    logical                      :: lout
        name=trim(line)
        if(len(name).ne.0)then
            lout = .true.                                  &
             & .and. verify(name(1:1), lower//upper) == 0  &
             & .and. verify(name,allowed) == 0             &
             & .and. len(name) <= 63
        else
            lout = .false.
        endif
    end function is_fortran_name

    subroutine set_help()
   help_list_nodash=[character(len=80) :: &
   'USAGE: fpm [ SUBCOMMAND [SUBCOMMAND_OPTIONS] ]|[--list|--help|--version]', &
   '       where SUBCOMMAND is commonly new|build|run|test                  ', &
   '                                                                        ', &
   ' subcommand may be one of                                               ', &
   '                                                                        ', &
   '  build     Compile the package placing results in the "build" directory', &
   '  help      Display help                                                ', &
   '  list      Display this list of subcommand descriptions                ', &
   '  new       Create a new Fortran package directory with sample files    ', &
   '  run       Run the local package application programs                  ', &
   '  test      Run the test programs                                       ', &
   '                                                                        ', &
   ' Enter "fpm --list" for a brief list of subcommand options. Enter       ', &
   ' "fpm --help" or "fpm SUBCOMMAND --help" for detailed descriptions.     ', &
   ' ']
   help_list_dash = [character(len=80) :: &
    '                                                                       ', &
   ' build [--release] [--list]                                             ', &
   ' help [NAME(s)]                                                         ', &
   ' new NAME [--lib|--src] [--app] [--test] [--backfill]                   ', &
   ' list [--list]                                                          ', &
   ' run [NAME(s)] [--release] [--list] [-- ARGS]                           ', &
   ' test [NAME(s)] [--release] [--list] [-- ARGS]                          ', &
   ' ']
    help_usage=[character(len=80) :: &
    '' ]
    help_fpm=[character(len=80) :: &
    'NAME                                                                   ', &
    '   fpm(1) - A Fortran package manager and build system                 ', &
    '                                                                       ', &
    'SYNOPSIS                                                               ', &
    '   fpm SUBCOMMAND [SUBCOMMAND_OPTIONS]                                 ', &
    '                                                                       ', &
    '   fpm --help|--version|--list                                         ', &
    '                                                                       ', &
    'DESCRIPTION                                                            ', &
    '   fpm(1) is a package manager that helps you create Fortran projects  ', &
    '   from source.                                                        ', &
    '                                                                       ', &
    '   Most significantly fpm(1) lets you draw upon other fpm(1) packages  ', &
    '   in distributed git(1) repositories as if the packages were a basic  ', &
    '   part of your default programming environment, as well as letting    ', &
    '   you share your projects with others in a similar manner.            ', &
    '                                                                       ', &
    '   See the fpm(1) repository at https://fortran-lang.org/packages/fpm  ', &
    '   for a listing of registered projects.                               ', &
    '                                                                       ', &
    '   All output goes into the directory "build/" which can generally be  ', &
    '   removed and rebuilt if required. Note that if external packages are ', &
    '   being used you need network connectivity to rebuild from scratch.   ', &
    '                                                                       ', &
    'SUBCOMMANDS                                                            ', &
    '  Valid fpm(1) subcommands are:                                        ', &
    '                                                                       ', &
    '     build [--release] [--list]                                        ', &
    '                     Compile the packages into the "build/" directory. ', &
    '     new NAME [--lib|--src] [--app] [--test] [--backfill]              ', &
    '                     Create a new Fortran package directory            ', &
    '                     with sample files                                 ', &
    '     run [NAME(s)] [--release] [--list] [-- ARGS]                      ', &
    '                     Run the local package binaries. defaults to all   ', &
    '                     binaries for that release.                        ', &
    '     test [NAME(s)] [--release] [--list] [-- ARGS]                     ', &
    '                     Run the tests                                     ', &
    '     help [NAME(s)]  Alternate method for displaying subcommand help   ', &
    '     list [--list]   Display brief descriptions of all subcommands.    ', &
    '                                                                       ', &
    'SUBCOMMAND OPTIONS                                                     ', &
    '  --release  Builds or runs in release mode (versus debug mode). fpm(1)', &
    '             Defaults to using common compiler debug flags and building', &
    '             in "build/*_debug/". When this flag is present build      ', &
    '             output goes into "build/*_release/" and common compiler   ', &
    '             optimization flags are used.                              ', &
    '  --list     List candidates instead of building or running them. On   ', &
    '             the fpm(1) command this shows a brief list of subcommands.', &
    '  -- ARGS    Arguments to pass to executables.                         ', &
    '  --help     Show help text and exit. Valid for all subcommands.       ', &
    '  --version  Show version information and exit. Valid for all          ', &
    '             subcommands.                                              ', &
    '                                                                       ', &
    'EXAMPLES                                                               ', &
    '   sample commands:                                                    ', &
    '                                                                       ', &
    '    fpm new mypackage --app --test                                     ', &
    '    fpm build                                                          ', &
    '    fpm test                                                           ', &
    '    fpm run                                                            ', &
    '    fpm new --help                                                     ', &
    '    fpm run myprogram --release -- -x 10 -y 20 --title "my title"      ', &
    '                                                                       ', &
    'SEE ALSO                                                               ', &
    '   The fpm(1) home page at https://github.com/fortran-lang/fpm         ', &
    '']
    help_list=[character(len=80) :: &
    'NAME                                                                   ', &
    ' list(1) - list summary of fpm(1) subcommands                          ', &
    '                                                                       ', &
    'SYNOPSIS                                                               ', &
    ' fpm list [-list]                                                      ', &
    '                                                                       ', &
    ' fpm list --help|--version                                             ', &
    '                                                                       ', &
    'DESCRIPTION                                                            ', &
    ' Display a short description for each fpm(1) subcommand.               ', &
    '                                                                       ', &
    'OPTIONS                                                                ', &
    ' --list     display a list of command options as well. This is the     ', &
    '            same output as generated by "fpm --list".                  ', &
    '                                                                       ', &
    'EXAMPLES                                                               ', &
    ' display a short list of fpm(1) subcommands                            ', &
    '                                                                       ', &
    '  fpm list                                                             ', &
    '  fpm --list                                                           ', &
    '                                                                       ', &
    'SEE ALSO                                                               ', &
    ' The fpm(1) home page at https://github.com/fortran-lang/fpm           ', &
    '' ]
    help_run=[character(len=80) :: &
    'NAME                                                                   ', &
    ' run(1) - the fpm(1) subcommand to run project applications            ', &
    '                                                                       ', &
    'SYNOPSIS                                                               ', &
    ' fpm run [NAME(s)] [--release] [-- ARGS]                               ', &
    '                                                                       ', &
    ' fpm run --help|--version                                              ', &
    '                                                                       ', &
    'DESCRIPTION                                                            ', &
    ' Run applications you have built in your fpm(1) project.               ', &
    '                                                                       ', &
    'OPTIONS                                                                ', &
    ' NAME(s)    optional list of specific names to execute.                ', &
    '            The default is to run all the applications in app/         ', &
    '            or the programs listed in the "fpm.toml" file.             ', &
    ' --release  selects the optimized build instead of the debug           ', &
    '            build.                                                     ', &
    ' --list     list candidates instead of building or running them        ', &
    ' -- ARGS    optional arguments to pass to the program(s).              ', &
    '            The same arguments are passed to all names                 ', &
    '            specified.                                                 ', &
    '                                                                       ', &
    'EXAMPLES                                                               ', &
    ' run fpm(1) project applications                                       ', &
    '                                                                       ', &
    '  # run default programs in /app or as specified in "fpm.toml"         ', &
    '  fpm run                                                              ', &
    '                                                                       ', &
    '  # run a specific program and pass arguments to the command           ', &
    '  fpm run mytest -- -x 10 -y 20 --title "my title line"                ', &
    '                                                                       ', &
    '  # run production version of two applications                         ', &
    '  fpm run prg1 prg2 --release                                          ', &
    '                                                                       ', &
    'SEE ALSO                                                               ', &
    ' The fpm(1) home page at https://github.com/fortran-lang/fpm           ', &
    '' ]
    help_build=[character(len=80) :: &
    'NAME                                                                   ', &
    ' build(1) - the fpm(1) subcommand to build a project                   ', &
    '                                                                       ', &
    'SYNOPSIS                                                               ', &
    ' fpm build [--release]|[-list]                                         ', &
    '                                                                       ', &
    ' fpm build --help|--version                                            ', &
    '                                                                       ', &
    'DESCRIPTION                                                            ', &
    ' The "fpm build" command                                               ', &
    '    o Fetches any dependencies                                         ', &
    '    o Scans your sources                                               ', &
    '    o Builds them in the proper order                                  ', &
    '                                                                       ', &
    ' The Fortran source files are assumed by default to be in              ', &
    '    o src/     for modules and procedure source                        ', &
    '    o app/     main program(s) for applications                        ', &
    '    o test/    main program(s) and support files for project tests     ', &
    ' Changed or new files found are rebuilt. The results are placed in     ', &
    ' the build/ directory.                                                 ', &
    '                                                                       ', &
    ' Non-default pathnames and remote dependencies are used if             ', &
    ' specified in the "fpm.toml" file.                                     ', &
    '                                                                       ', &
    'OPTIONS                                                                ', &
    ' --release  build in build/*_release instead of build/*_debug with     ', &
    '            high optimization instead of full debug options.           ', &
    ' --list     list candidates instead of building or running them        ', &
    ' --help     print this help and exit                                   ', &
    ' --version  print program version information and exit                 ', &
    '                                                                       ', &
    'EXAMPLES                                                               ', &
    ' Sample commands:                                                      ', &
    '                                                                       ', &
    '  fpm build           # build with debug options                       ', &
    '  fpm build --release # build with high optimization                   ', &
    '                                                                       ', &
    'SEE ALSO                                                               ', &
    ' The fpm(1) home page at https://github.com/fortran-lang/fpm           ', &
    '' ]

    help_help=[character(len=80) :: &
    'NAME                                                                   ', &
    '   help(1) - the fpm(1) subcommand to display help                     ', &
    '                                                                       ', &
    'SYNOPSIS                                                               ', &
    '   fpm help [fpm] [new] [build] [run] [test] [help] [version] [manual] ', &
    '                                                                       ', &
    'DESCRIPTION                                                            ', &
    '   The "fpm help" command is an alternative to the --help parameter    ', &
    '   on the fpm(1) command and its subcommands.                          ', &
    '                                                                       ', &
    'OPTIONS                                                                ', &
    '   NAME(s)    A list of topic names to display. All the subcommands    ', &
    '              have their own page (new, build, run, test, ...).        ', &
    '                                                                       ', &
    '              The special name "manual" displays all the fpm(1)        ', &
    '              built-in documentation.                                  ', &
    '                                                                       ', &
    '              The default is to display help for the fpm(1) command    ', &
    '              itself.                                                  ', &
    '                                                                       ', &
    'EXAMPLES                                                               ', &
    '   Sample usage:                                                       ', &
    '                                                                       ', &
    '     fpm help           # general fpm(1) command help                  ', &
    '     fpm help version   # show program version                         ', &
    '     fpm help new       # display help for "new" subcommand            ', &
    '     fpm help manual    # All fpm(1) built-in documentation            ', &
    '                                                                       ', &
    'SEE ALSO                                                               ', &
    '   The fpm(1) home page at https://github.com/fortran-lang/fpm         ', &
    '' ]
    help_new=[character(len=80) ::                                             &
    'NAME                                                                   ', &
    ' new(1) - the fpm(1) subcommand to initialize a new project            ', &
    'SYNOPSIS                                                               ', &
    ' fpm new NAME [--lib|--src] [--app] [--test] [--backfill]              ', &
    '                                                                       ', &
    ' fpm new --help|--version                                              ', &
    '                                                                       ', &
    'DESCRIPTION                                                            ', &
    ' "fpm new" creates and populates a new programming project directory.  ', &
    ' It                                                                    ', &
    '   o creates a directory with the specified name                       ', &
    '   o runs the command "git init" in that directory                     ', &
    '   o populates the directory with the default project directories      ', &
    '   o adds sample Fortran source files                                  ', &
    '   o adds a ".gitignore" file for ignoring the build/ directory        ', &
    '     (where fpm-generated output will be placed)                       ', &
    '                                                                       ', &
    ' The basic default file structure is                                   ', &
    '                                                                       ', &
    '     NAME/                                                             ', &
    '       fpm.toml                                                        ', &
    '       .gitignore                                                      ', &
    '       src/                                                            ', &
    '           NAME.f90                                                    ', &
    '       app/                                                            ', &
    '           main.f90                                                    ', &
    '       test/                                                           ', &
    '           main.f90                                                    ', &
    '                                                                       ', &
    ' Remember to update the information in the sample "fpm.toml"           ', &
    ' file with your name and e-mail address.                               ', &
    '                                                                       ', &
    'OPTIONS                                                                ', &
    ' NAME   the name of the project directory to create. The name          ', &
    '        must be a valid Fortran name composed of 1 to 63               ', &
    '        ASCII alphanumeric characters and underscores,                 ', &
    '        starting with a letter.                                        ', &
    '                                                                       ', &
    ' The default is to create all of the src/, app/, and test/             ', &
    ' directories. If any of the following options are specified            ', &
    ' then only selected subdirectories are generated:                      ', &
    '                                                                       ', &
    ' --lib,--src  create directory src/ and a placeholder module           ', &
    '              named "NAME.f90" for use with subcommand "build".        ', &
    ' --app        create directory app/ and a placeholder main             ', &
    '              program for use with subcommand "run".                   ', &
    ' --test       create directory test/ and a placeholder program         ', &
    '              for use with the subcommand "test". Note that sans       ', &
    '              "--lib" it really does not have anything to test.        ', &
    '                                                                       ', &
    ' So the default is equivalent to "fpm NAME --lib --app --test".        ', &
    '                                                                       ', &
    ' --backfill   By default the directory must not exist. If this         ', &
    '              option is present the directory may pre-exist and        ', &
    '              only subdirectories and files that do not                ', &
    '              already exist will be created. For example, if you       ', &
    '              previously entered "fpm new myname --lib" entering       ', &
    '              "fpm new myname --backfill" will create the missing      ', &
    '              app/ and test/ directories and programs.                 ', &
    '                                                                       ', &
    ' --help       print this help and exit                                 ', &
    ' --version    print program version information and exit               ', &
    '                                                                       ', &
    'EXAMPLES                                                               ', &
    ' Sample use                                                            ', &
    '                                                                       ', &
    '   fpm new myproject  # create new project directory and seed it       ', &
    '   cd myproject       # Enter the new directory                        ', &
    '   # and run commands such as                                          ', &
    '   fpm build                                                           ', &
    '   fpm run            # run example application program                ', &
    '   fpm test           # run example test program                       ', &
    '                                                                       ', &
    'SEE ALSO                                                               ', &
    ' The fpm(1) home page at https://github.com/fortran-lang/fpm           ', &
    '                                                                       ', &
    ' Registered packages are at https://fortran-lang.org/packages          ', &
    '' ]
    help_test=[character(len=80) :: &
    'NAME                                                                   ', &
    ' test(1) - the fpm(1) subcommand to run project tests                  ', &
    '                                                                       ', &
    'SYNOPSIS                                                               ', &
    ' fpm test [NAME(s)] [--release] [--list] [-- ARGS]                     ', &
    '                                                                       ', &
    ' fpm test --help|--version                                             ', &
    '                                                                       ', &
    'DESCRIPTION                                                            ', &
    ' Run applications you have built to test your project.                 ', &
    '                                                                       ', &
    'OPTIONS                                                                ', &
    ' NAME(s)    optional list of specific test names to execute.           ', &
    '            The default is to run all the tests in test/               ', &
    '            or the tests listed in the "fpm.toml" file.                ', &
    ' --release  selects the optimized build instead of the debug           ', &
    '            build.                                                     ', &
    ' --list     list candidates instead of building or running them        ', &
    ' -- ARGS    optional arguments to pass to the test program(s).         ', &
    '            The same arguments are passed to all test names            ', &
    '            specified.                                                 ', &
    '                                                                       ', &
    'EXAMPLES                                                               ', &
    'run tests                                                              ', &
    '                                                                       ', &
    ' # run default tests in /test or as specified in "fpm.toml"            ', &
    ' fpm test                                                              ', &
    '                                                                       ', &
    ' # run a specific test and pass arguments to the command               ', &
    ' fpm test mytest -- -x 10 -y 20 --title "my title line"                ', &
    '                                                                       ', &
    ' fpm test tst1 tst2 --release # production version of two tests        ', &
    '                                                                       ', &
    'SEE ALSO                                                               ', &
    ' The fpm(1) home page at https://github.com/fortran-lang/fpm           ', &
    '' ]
    help_install=[character(len=80) :: &
    ' fpm(1) subcommand "install"                                           ', &
    '                                                                       ', &
    ' USAGE: fpm install NAME                                               ', &
    '' ]
    end subroutine set_help

end module fpm_command_line

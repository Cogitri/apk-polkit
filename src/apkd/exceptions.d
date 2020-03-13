module apkd.exceptions;

@safe:
nothrow:

/// Superclass for all kind of failures in apk-tools
class ApkException : Exception
{
    this(string msg, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line);
    }
}

/// Thrown if solving the dependency graph fails
class ApkSolverException : ApkException
{
    this(string msg, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line);
    }
}

/// Thrown if commiting a changeset to the databse
class ApkDatabaseCommitException : ApkException
{
    this(string msg, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line);
    }
}

/// Thrown if opening the database fails
class ApkDatabaseOpenException : ApkException
{
    this(string msg, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line);
    }
}

/// Thrown if the repo can't be updated
class ApkRepoUpdateException : ApkException
{
    this(string msg, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line);
    }
}

/// Superclass for user caused errors
class UserErrorException : Exception
{
    this(string msg, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line);
    }
}

/// Thrown if the specified package can't be found
class NoSuchPackageFoundException : UserErrorException
{
    this(string msg, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line);
    }
}

/// Thrown if dependency constraint format by the user is invalid
class BadDependencyFormatException : UserErrorException
{
    this(string msg, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line);
    }
}

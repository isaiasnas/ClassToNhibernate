IF OBJECT_ID('dbo.app_who') IS NOT NULL
    DROP PROCEDURE dbo.app_who;
GO
CREATE PROCEDURE dbo.app_who(@base  VARCHAR(100) = '',
                             @host  VARCHAR(100) = '',
                             @order INT          = 1,
                             @oAsc  VARCHAR(100) = 'asc',
                             @kill  INT          = NULL,
                             @block VARCHAR(50)  = NULL)
WITH ENCRYPTION
AS
     BEGIN
         SET NOCOUNT ON;
         SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
         DECLARE @table AS TABLE
         (spid     VARCHAR(100),
          status   VARCHAR(100),
          login    VARCHAR(100),
          host     VARCHAR(100),
          block    VARCHAR(100),
          base     VARCHAR(100),
          comando  VARCHAR(100),
          cpu      VARCHAR(100),
          disk     VARCHAR(100),
          data     VARCHAR(100),
          programa VARCHAR(100)
         );
         IF(@base IN('?', 'help', '-?', '-h', '-help', '- help'))
             BEGIN
                 PRINT 'Parametros: -> @base varchar(100),@host varchar(100),@order INT,@oAsc varchar(100),@kill int'+CHAR(13);
                 PRINT '@base  -> nome do banco';
                 PRINT '@host  -> sevidor';
                 PRINT '@order -> ordenação por coluna, valor numerico, Ex:1 coluna [1]....';
                 PRINT '@oAsc  -> direção da ordenação sobre o parametro anterior, [asc|desc]';
                 PRINT '@kill  -> SPID  a ser derrubado, Ex: 5, executara o comando [derrubara a sessão 5]';
                 RETURN;
             END;
         DECLARE @orderChar VARCHAR(50)= '';
         DECLARE @filter VARCHAR(1000)= 'where 1=1 ';
         IF @host <> ''
             BEGIN
                 SET @filter = @filter+' and host='''+@host+'''';
             END;
         IF @base <> ''
             BEGIN
                 SET @filter = @filter+' and base='''+@base+'''';
             END;
         SET @order = ISNULL(@order, 1);
         SET @oAsc = (CASE
                          WHEN @oAsc IS NULL
                          THEN 'asc'
                          ELSE @oAsc
                      END);
         SET @oAsc = (CASE
                          WHEN @oAsc NOT IN('asc', 'desc')
                          THEN 'asc'
                          ELSE @oAsc
                      END);
         SET @kill = ISNULL(@kill, 0);
         SET @block = (CASE
                           WHEN @block IS NULL
                           THEN ''
                           ELSE ' and block <>''''  '
                       END);
         SET @filter = @filter + @block;
         SET @orderChar = (CASE @order
                               WHEN 1
                               THEN 'spid'
                               WHEN 2
                               THEN 'status'
                               WHEN 3
                               THEN 'login'
                               WHEN 4
                               THEN 'host'
                               WHEN 5
                               THEN 'block'
                               WHEN 6
                               THEN 'base'
                               WHEN 7
                               THEN 'comando'
                               WHEN 8
                               THEN 'cpu'
                               WHEN 9
                               THEN 'disk'
                               WHEN 10
                               THEN 'data'
                               WHEN 11
                               THEN 'programa'
                               ELSE 'spid'
                           END);
         DECLARE @loginame SYSNAME= NULL, @retcode INT;
         DECLARE @sidlow VARBINARY(85), @sidhigh VARBINARY(85), @sid1 VARBINARY(85), @spidlow INT, @spidhigh INT;
         DECLARE @charMaxLenLoginName VARCHAR(6), @charMaxLenDBName VARCHAR(6), @charMaxLenCPUTime VARCHAR(10), @charMaxLenDiskIO VARCHAR(10), @charMaxLenHostName VARCHAR(10), @charMaxLenProgramName VARCHAR(10), @charMaxLenLastBatch VARCHAR(10), @charMaxLenCommand VARCHAR(10);
         DECLARE @charsidlow VARCHAR(85), @charsidhigh VARCHAR(85), @charspidlow VARCHAR(11), @charspidhigh VARCHAR(11);
         -- defaults
         SELECT @retcode = 0;      -- 0=good ,1=bad.
         SELECT @sidlow = CONVERT( VARBINARY(85), REPLICATE(CHAR(0), 85));
         SELECT @sidhigh = CONVERT( VARBINARY(85), REPLICATE(CHAR(1), 85));
         SELECT @spidlow = 0,
                @spidhigh = 32767;
         --------------------------------------------------------------
         IF @loginame IS NULL  --Simple default to all LoginNames.
             GOTO LABEL_17PARM1EDITED;
         -- select @sid1 = suser_sid(@loginame)
         SELECT @sid1 = NULL;
         IF EXISTS
         (
             SELECT *
             FROM sys.syslogins
             WHERE loginname = @loginame
         )
             SELECT @sid1 = sid
             FROM sys.syslogins
             WHERE loginname = @loginame;
         IF @sid1 IS NOT NULL  --Parm is a recognized login name.
             BEGIN
                 SELECT @sidlow = SUSER_SID(@loginame),
                        @sidhigh = SUSER_SID(@loginame);
                 GOTO LABEL_17PARM1EDITED;
             END;
         --------
         IF LOWER(@loginame COLLATE Latin1_General_CI_AS) IN('active')  --Special action, not sleeping.
             BEGIN
                 SELECT @loginame = LOWER(@loginame COLLATE Latin1_General_CI_AS);
                 GOTO LABEL_17PARM1EDITED;
             END;
         --------
         IF PATINDEX('%[^0-9]%', ISNULL(@loginame, 'z')) = 0  --Is a number.
             BEGIN
                 SELECT @spidlow = CONVERT(  INT, @loginame),
                        @spidhigh = CONVERT( INT, @loginame);
                 GOTO LABEL_17PARM1EDITED;
             END;
         --------
         RAISERROR(15007, -1, -1, @loginame);
         SELECT @retcode = 1;
         GOTO LABEL_86RETURN;
         LABEL_17PARM1EDITED:
         --------------------  Capture consistent sysprocesses.  -------------------
         SELECT spid,
                status,
                sid,
                hostname,
                program_name,
                cmd,
                cpu,
                physical_io,
                blocked,
                dbid,
                CONVERT(   SYSNAME, RTRIM(loginame)) AS loginname,
                spid AS 'spid_sort',
                SUBSTRING(CONVERT( VARCHAR, last_batch, 111), 6, 5)+' '+SUBSTRING(CONVERT(VARCHAR, last_batch, 113), 13, 8) AS 'last_batch_char',
                last_batch AS 'DT',
                request_id
         INTO #tb1_sysprocesses
         FROM sys.sysprocesses WITH (nolock);
         IF @@error <> 0
             BEGIN
                 SELECT @retcode = @@error;
                 GOTO LABEL_86RETURN;
             END;
         --------Screen out any rows?
         IF @loginame IN('active')
             DELETE #tb1_sysprocesses
             WHERE LOWER(status) = 'sleeping'
                   AND UPPER(cmd) IN('AWAITING COMMAND', 'LAZY WRITER', 'CHECKPOINT SLEEP')
             AND blocked = 0;
         --------Prepare to dynamically optimize column widths.
         SELECT @charsidlow = CONVERT(   VARCHAR(85), @sidlow),
                @charsidhigh = CONVERT(  VARCHAR(85), @sidhigh),
                @charspidlow = CONVERT(  VARCHAR, @spidlow),
                @charspidhigh = CONVERT( VARCHAR, @spidhigh);
         SELECT @charMaxLenLoginName = CONVERT(   VARCHAR, ISNULL(MAX(DATALENGTH(loginname)), 5)),
                @charMaxLenDBName = CONVERT(      VARCHAR, ISNULL(MAX(DATALENGTH(RTRIM(CONVERT(VARCHAR(128), DB_NAME(dbid))))), 6)),
                @charMaxLenCPUTime = CONVERT(     VARCHAR, ISNULL(MAX(DATALENGTH(RTRIM(CONVERT(VARCHAR(128), cpu)))), 7)),
                @charMaxLenDiskIO = CONVERT(      VARCHAR, ISNULL(MAX(DATALENGTH(RTRIM(CONVERT(VARCHAR(128), physical_io)))), 6)),
                @charMaxLenCommand = CONVERT(     VARCHAR, ISNULL(MAX(DATALENGTH(RTRIM(CONVERT(VARCHAR(128), cmd)))), 7)),
                @charMaxLenHostName = CONVERT(    VARCHAR, ISNULL(MAX(DATALENGTH(RTRIM(CONVERT(VARCHAR(128), hostname)))), 8)),
                @charMaxLenProgramName = CONVERT( VARCHAR, ISNULL(MAX(DATALENGTH(RTRIM(CONVERT(VARCHAR(128), program_name)))), 11)),
                @charMaxLenLastBatch = CONVERT(   VARCHAR, ISNULL(MAX(DATALENGTH(RTRIM(CONVERT(VARCHAR(128), last_batch_char)))), 9))
         FROM #tb1_sysprocesses
         WHERE spid >= @spidlow
               AND spid <= @spidhigh;
         --------Output the report.
         INSERT INTO @TABLE
         EXEC ('

SELECT
			 SPID          

			,STATUS        =
				  CASE lower(status)
					 When ''sleeping'' Then lower(status)
					 Else                   upper(status)
				  END

			,LOGIN         = substring(loginname,1,'+@charMaxLenLoginName+')

			,HOST      =
				  rtrim(ltrim(CASE hostname
					 When Null  Then ''''
					 When '' '' Then ''''
					 Else    substring(hostname,1,'+@charMaxLenHostName+')
				  END))

			,BLOCK         =
				  CASE               isnull(convert(char(5),blocked),''0'')
					 When ''0'' Then ''''
					 Else            isnull(convert(char(5),blocked),''0'')
				  END

			,BASE        = substring(case when dbid = 0 then null when dbid <> 0 then db_name(dbid) end,1,'+@charMaxLenDBName+')
			,COMANDO       = substring(cmd,1,'+@charMaxLenCommand+')

			,CPU       = cast(substring(convert(varchar,cpu),1,'+@charMaxLenCPUTime+')as bigint)
			,DISK        = cast(substring(convert(varchar,physical_io),1,'+@charMaxLenDiskIO+')as bigint)


			,DATA     = cast(DT as datetime2)
			,PROGRAMA   = substring(program_name,1,'+@charMaxLenProgramName+')
	   into #tempDbBase
	  from
			 #tb1_sysprocesses  --Usually DB qualification is needed in exec().
	  where
			 spid >= '+@charspidlow+'
	  and    spid <= '+@charspidhigh+'
	  --order by '+@order+'
	  SELECT * FROM  #tempDbBase '+@filter+' order by '+@orderChar+' '+@oAsc+' 
	  IF OBJECT_ID(''tempdb..#tempDbBase'') IS NOT NULL DROP TABLE #tempDbBase;
SET nocount on
');
         LABEL_86RETURN:
         IF OBJECT_ID('tempdb..#tb1_sysprocesses') IS NOT NULL
             DROP TABLE #tb1_sysprocesses;
         SET NOCOUNT OFF;
     END;
         SELECT *
         FROM @TABLE;
         PRINT '@base  -> '+@base;
         PRINT '@host  -> '+@host;
         PRINT '@order -> '+@orderChar;
         PRINT '@oAsc  -> '+@oAsc;
         PRINT '@kill  -> '+CAST(@kill AS VARCHAR);
GO
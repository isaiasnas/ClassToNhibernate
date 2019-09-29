IF OBJECT_ID('[dbo].[create_class]') IS NOT NULL DROP PROCEDURE [dbo].[create_class];
GO

CREATE PROCEDURE [dbo].[create_class]
(@tabela        SYSNAME, 
 @serializacao  BIT          = 0, 
 @comentario    BIT          = 0, 
 @override      BIT          = 0, 
 @overrideFull  BIT          = 0, 
 @generic       BIT          = 0, 
 @baseClassName VARCHAR(500) = ''
)
AS
    BEGIN
        IF @tabela = '?'
            BEGIN
                PRINT 'procedimento responsavel por criar classe referente a tabela apresentada';
                PRINT 'parametros' + CHAR(13);
                PRINT '1- @tabela<SYSNAME>:= nome da tabela no banco de dados';
                PRINT '2- @serializacao<BIT>:= [1|0] 1:apresenta [Serializable],0:suprime';
                PRINT '3- @comentario<BIT>:= [1|0] 1:apresenta comentário das colunas,0:suprime';
                PRINT '4- @override<BIT>:= [1|0] 1:caso queira sobeescrever métodos [Equals|GetHashCode|ToString],0:suprime';
                PRINT '5- @@overrideFull<BIT>:= [1|0] 1:caso queira sobeescrever métodos [Equals|GetHashCode|ToString] detalhado,0:suprime';
                PRINT '6- @generic<BIT>:= [1|0] 1:caso queira usar uma classe base de forma generica,0:suprime';
                PRINT '7- @baseClassName<VARCHAR(500)>:= caso [@generic=1] e valor passado usa classe generica, caso [@generic=0] e valor passado usa somente classe passada';
                RETURN;
        END;
        DECLARE @TableName SYSNAME= @tabela;
        DECLARE @ClassBase VARCHAR(MAX);
        IF @generic = 1
           AND @baseClassName IS NOT NULL
           AND LEN(@baseClassName) > 0
            BEGIN
                SET @ClassBase = '' + @baseClassName + '<' + @TableName + '>';
        END;
        IF @generic = 0
           AND @baseClassName IS NOT NULL
           AND LEN(@baseClassName) > 0
            BEGIN
                SET @ClassBase = '' + @baseClassName;
        END;
        DECLARE @Result VARCHAR(MAX)= '';
        DECLARE @count INT=
        (
            SELECT COUNT(*)
            FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
            WHERE OBJECTPROPERTY(OBJECT_ID(CONSTRAINT_SCHEMA + '.' + QUOTENAME(CONSTRAINT_NAME)), 'IsPrimaryKey') = 1
                  AND TABLE_NAME = @tabela
        );
        IF @comentario = 1
            BEGIN
                SELECT @Result = @Result + '/// <summary>              
/// [Tabela]=>' + @TableName;
                SELECT @Result = @Result + '              
/// <para> [Chave]=> ' + CONSTRAINT_NAME + ', [Coluna]=> ' + COLUMN_NAME + ', [Ordem]=> ' + CAST(ORDINAL_POSITION AS VARCHAR(MAX)) + '</para>'
                FROM
                (
                    SELECT TOP 100 *
                    FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
                    WHERE OBJECTPROPERTY(OBJECT_ID(CONSTRAINT_SCHEMA + '.' + QUOTENAME(CONSTRAINT_NAME)), 'IsPrimaryKey') = 1
                          AND TABLE_NAME = @tabela
                    ORDER BY ORDINAL_POSITION
                ) t;
        END;
        SELECT @Result = @Result + CASE
                                       WHEN @comentario = 1
                                       THEN '          
/// </summary>'
                                       ELSE+CASE
                                                WHEN @serializacao = 1
                                                THEN '          
[Serializable]'
                                                ELSE ''
                                            END
                                   END + CASE
                                             WHEN @serializacao = 1
                                             THEN '          
[Serializable]'
                                             ELSE ''
                                         END + '           
public class ' + @TableName + ' ' + CASE
                                        WHEN(@ClassBase IS NULL
                                             OR @ClassBase = '')
                                        THEN ''
                                        ELSE ': ' + @ClassBase
                                    END + '              
{';
        SELECT @Result = @Result + CASE
                                       WHEN @comentario = 1
                                       THEN '            
	/// <summary>              
    /// [Tabela]=>' + @TableName + ', [Coluna]=> ' + ColumnName + ', [tamanho]=> ' + t.max + '              
    /// </summary>'
                                       ELSE ''
                                   END + '              
    public virtual ' + ColumnType + NullableSign + ' ' + ColumnName + ' { get; set; }'
        FROM
        (
            SELECT replace(col.name, ' ', '_') ColumnName, 
                   column_id ColumnId, 
                   CAST(col.max_length AS VARCHAR(MAX)) max,
                   CASE typ.name
                       WHEN 'bigint'
                       THEN 'long'
                       WHEN 'binary'
                       THEN 'byte[]'
                       WHEN 'bit'
                       THEN 'bool'
                       WHEN 'char'
                       THEN 'string'
                       WHEN 'date'
                       THEN 'DateTime'
                       WHEN 'datetime'
                       THEN 'DateTime'
                       WHEN 'datetime2'
                       THEN 'DateTime'
                       WHEN 'datetimeoffset'
                       THEN 'DateTimeOffset'
                       WHEN 'decimal'
                       THEN 'decimal'
                       WHEN 'float'
                       THEN 'double'
                       WHEN 'image'
                       THEN 'byte[]'
                       WHEN 'int'
                       THEN 'int'
                       WHEN 'money'
                       THEN 'decimal'
                       WHEN 'nchar'
                       THEN 'string'
                       WHEN 'ntext'
                       THEN 'string'
                       WHEN 'numeric'
                       THEN 'decimal'
                       WHEN 'nvarchar'
                       THEN 'string'
                       WHEN 'real'
                       THEN 'float'
                       WHEN 'smalldatetime'
                       THEN 'DateTime'
                       WHEN 'smallint'
                       THEN 'short'
                       WHEN 'smallmoney'
                       THEN 'decimal'
                       WHEN 'text'
                       THEN 'string'
                       WHEN 'time'
                       THEN 'TimeSpan'
                       WHEN 'timestamp'
                       THEN 'long'
                       WHEN 'tinyint'
                       THEN 'byte'
                       WHEN 'uniqueidentifier'
                       THEN 'Guid'
                       WHEN 'varbinary'
                       THEN 'byte[]'
                       WHEN 'varchar'
                       THEN 'string'
                       ELSE 'UNKNOWN_' + typ.name
                   END ColumnType,
                   CASE
                       WHEN col.is_nullable = 1
                            AND typ.name IN('bigint', 'bit', 'date', 'datetime', 'datetime2', 'datetimeoffset', 'decimal', 'float', 'int', 'money', 'numeric', 'real', 'smalldatetime', 'smallint', 'smallmoney', 'time', 'tinyint', 'uniqueidentifier')
                       THEN '?'
                       ELSE ''
                   END NullableSign
            FROM sys.columns col
                 JOIN sys.types typ ON col.system_type_id = typ.system_type_id
                                       AND col.user_type_id = typ.user_type_id
            WHERE object_id = OBJECT_ID(@TableName) AND col.name<>'OptimisticLockField'
        ) t
        ORDER BY ColumnId;
        IF @count > 0
           AND @override = 1
           AND @overrideFull = 0
            BEGIN
               SELECT @Result = @Result + '          
	' + CASE
         WHEN @comentario = 1
         THEN '          
	/// <summary>              
    /// Sobrecarga Equals()          
    /// </summary>'
         ELSE ''
     END + '       
	public override bool Equals(object obj) => Equals(obj as ' + @tabela + ');
      
	/// <summary>              
    /// Verificação interna de igualdade()          
    /// </summary>  
	private bool Equals(' + @tabela + ' o)          
	{          
		if (ReferenceEquals(this, o)) return true;  
        if (ReferenceEquals(null, o)) return false;  
    
		return';
                SELECT @Result = @Result + '              
		' + COLUMN_NAME + ' == o.' + COLUMN_NAME + ' &&'
                FROM
                (
                    SELECT TOP 100 *
                    FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
                    WHERE OBJECTPROPERTY(OBJECT_ID(CONSTRAINT_SCHEMA + '.' + QUOTENAME(CONSTRAINT_NAME)), 'IsPrimaryKey') = 1
                          AND TABLE_NAME = @tabela
                    ORDER BY ORDINAL_POSITION
                ) t;
                SET @Result = SUBSTRING(@Result, 0, LEN(@Result) - 1);
                SET @Result = +@Result + ';                    
	}  
 ' + CASE
         WHEN @comentario = 1
         THEN '            
	/// <summary>              
    /// Sobrecarga GetHashCode()          
    /// </summary>'
         ELSE '          
     '
     END + '          
	public override int GetHashCode()          
	{          
		int hash = GetType().GetHashCode();';
                SELECT @Result = @Result + '              
		hash = (hash * 7) + ' + COLUMN_NAME + CASE
                                            WHEN t.COLLATION_NAME IS NULL
                                            THEN '.GetHashCode();'
                                            ELSE '?.GetHashCode() ?? 1;'
                                        END
                FROM
                (
                    SELECT TOP 100 a.COLUMN_NAME, 
                                   b.COLLATION_NAME
                    FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE a
                         LEFT JOIN INFORMATION_SCHEMA.COLUMNS b ON(a.TABLE_CATALOG = b.TABLE_CATALOG
                                                                   AND a.TABLE_SCHEMA = b.TABLE_SCHEMA
                                                                   AND a.TABLE_NAME = b.TABLE_NAME
                                                                   AND a.COLUMN_NAME = b.COLUMN_NAME
                                                                   AND a.ORDINAL_POSITION = b.ORDINAL_POSITION)
                    WHERE OBJECTPROPERTY(OBJECT_ID(a.CONSTRAINT_SCHEMA + '.' + QUOTENAME(a.CONSTRAINT_NAME)), 'IsPrimaryKey') = 1
                          AND a.TABLE_NAME = @tabela
                    ORDER BY a.ORDINAL_POSITION
                ) t;
                SELECT @Result = @Result + '           
		return hash;          
	}  
 ' + CASE
         WHEN @comentario = 1
         THEN '            
	/// <summary>              
    /// Sobrecarga ToString()          
    /// </summary>'
         ELSE '          
     '
     END + '          
	public override string ToString()         
    {          
        return base.ToString();          
    }          
}';
        END;
            ELSE
            IF @count > 0
               AND @override = 1
               AND @overrideFull = 1
                BEGIN
                    SELECT @Result = @Result + '          
' + CASE
        WHEN @comentario = 1
        THEN '          
	/// <summary>              
    /// Sobrecarga Equals()          
    /// </summary>'
        ELSE ''
    END + '      
	public override bool Equals(object obj) => Equals(obj as ' + @tabela + ');
       
	private bool Equals(' + @tabela + ' obj)          
	{     
		if (ReferenceEquals(this, obj)) return true;  
        if (ReferenceEquals(null, obj)) return false;';
                    SELECT @Result = @Result + '              
			' + COLUMN_NAME + ' != o.' + COLUMN_NAME + ' &&'
                    FROM
                    (
                        SELECT TOP 100 a.COLUMN_NAME, 
                                       a.COLLATION_NAME
                        FROM INFORMATION_SCHEMA.COLUMNS a
                        WHERE a.TABLE_NAME = @tabela AND a.COLUMN_NAME<>'OptimisticLockField'
                        ORDER BY a.ORDINAL_POSITION
                    ) t;
                    SET @Result = SUBSTRING(@Result, 0, LEN(@Result) - 1);
                    SELECT @Result = 'return ' + @Result + ';                
 }' + CASE
          WHEN @comentario = 1
          THEN '            
	/// <summary>              
    /// Sobrecarga GetHashCode()          
    /// </summary>'
          ELSE '          
     '
      END + '          
	public override int GetHashCode()          
	{          
		int hash = GetType().GetHashCode();';
                    SELECT @Result = @Result + '              
		hash = (hash * 7) + ' + COLUMN_NAME + CASE
                                                    WHEN t.COLLATION_NAME IS NULL
                                                    THEN '.GetHashCode();'
                                                    ELSE '?.GetHashCode() ?? 1;'
                                                END
                    FROM
                    (
                        SELECT TOP 100 a.COLUMN_NAME, 
                                       a.COLLATION_NAME
                        FROM INFORMATION_SCHEMA.COLUMNS a
                        WHERE a.TABLE_NAME = @tabela AND a.COLUMN_NAME<>'OptimisticLockField'
                        ORDER BY a.ORDINAL_POSITION
                    ) t;          
                    --SET @Result = SUBSTRING(@Result, 0, LEN(@Result) - 1);     
                    SELECT @Result = @Result + '           
	return hash;          
 }' + CASE
          WHEN @comentario = 1
          THEN '            
	/// <summary>              
    /// Sobrecarga ToString()          
    /// </summary>'
          ELSE '          
     '
      END + '          
	public override string ToString()          
    {          
        return base.ToString();          
    }          
}';
            END;
                ELSE
                SELECT @Result = @Result + '          
}';
        SELECT CAST(@Result AS NTEXT);
    END;
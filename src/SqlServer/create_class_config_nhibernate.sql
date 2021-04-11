IF OBJECT_ID('[dbo].[create_class_config_nhibernate]') IS NOT NULL DROP PROCEDURE [dbo].[create_class_config_nhibernate];
GO

CREATE PROCEDURE [dbo].[create_class_config_nhibernate](@tabela SYSNAME, @tabelaAlias VARCHAR(50) = '')  
AS  
    BEGIN  
        DECLARE @TableName SYSNAME= @tabela;  
		DECLARE @ALIAS VARCHAR(50)= case when @tabelaAlias='' then @TableName else @tabelaAlias end;
        DECLARE @ClassBase VARCHAR(100)= 'DtoBase<' + @TableName + '>';  
        DECLARE @Result VARCHAR(MAX)= '';  
        SELECT @Result = @Result + 'internal class ' + @ALIAS + 'Config : ConfigBase<' + @ALIAS + '> , IEasyDataAccess  
{  
	public ' + @ALIAS + 'Config() : base("'+ @TableName +'") { }

	protected override void Setup()
    {';  
        SELECT @Result = @Result + '  
	//Id(m => m.' + COLUMN_NAME + ');'  
        FROM  
        (  
            SELECT TOP 100 *  
            FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE  
            WHERE OBJECTPROPERTY(OBJECT_ID(CONSTRAINT_SCHEMA + '.' + QUOTENAME(CONSTRAINT_NAME)), 'IsPrimaryKey') = 1  
                  AND TABLE_NAME = @tabela  
            ORDER BY ORDINAL_POSITION  
        ) t;  
        --//Id(m => m.{});'  
        SELECT @Result = @Result + '  
	Cl(m => m.' + ColumnName + ').Column("'+ ColumnName +'")'+NameSql+MaxL+Number+';'  
        FROM  
        (  
            SELECT replace(col.name, ' ', '_') ColumnName,   
                   column_id ColumnId,
				   '.CustomSqlType("'+ typ.name +'")' NameSql,
				   CASE WHEN typ.collation_name IS NOT NULL THEN '.Length('+cast(col.max_length AS varchar(100))+')' ELSE '' end MaxL,
				   CASE WHEN typ.name in('numeric','decimal','money') THEN '.Precision('+cast(col.precision AS varchar(100))+').Scale('+cast(col.scale AS varchar(100))+')' ELSE '' end Number
            FROM sys.columns col  
                 JOIN sys.types typ ON col.system_type_id = typ.system_type_id  
                                       AND col.user_type_id = typ.user_type_id  
            WHERE object_id = OBJECT_ID(@TableName)   AND col.name<>'OptimisticLockField' 
        ) t  
        ORDER BY ColumnId;  
        SET @Result = @Result + '  
	}  
}';  
        select @Result;  
    END;
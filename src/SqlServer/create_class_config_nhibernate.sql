IF OBJECT_ID('[dbo].[create_class_config_nhibernate]') IS NOT NULL DROP PROCEDURE [dbo].[create_class_config_nhibernate];
GO

CREATE PROCEDURE [dbo].[create_class_config_nhibernate](@tabela SYSNAME, @tabelaAlias VARCHAR(50) = '',@dominio bit = 0)  
AS  
    BEGIN  
		DECLARE @Count int;
        DECLARE @TableName SYSNAME= @tabela;  
		DECLARE @ALIAS VARCHAR(50)= case when @tabelaAlias='' then @TableName else @tabelaAlias end;
        DECLARE @ClassBase VARCHAR(100)= 'DtoBase<' + @TableName + '>';  
        DECLARE @Result VARCHAR(MAX)= '';  
        DECLARE @Keys VARCHAR(MAX)= '';  
		SET @Count=(SELECT count(*)  
            FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE  
            WHERE OBJECTPROPERTY(OBJECT_ID(CONSTRAINT_SCHEMA + '.' + QUOTENAME(CONSTRAINT_NAME)), 'IsPrimaryKey') = 1  
                  AND TABLE_NAME = @tabela);

        SELECT @Result = @Result + 'internal class ' + @ALIAS + 'ConfigRepo : ConfigBase<' + @ALIAS + '> '+case when (@dominio = 1 and @Count > 0) then ', IEasyDataAccess' else '' end+
'{  
	public ' + @ALIAS + 'ConfigRepo() : base("'+ @TableName +'") { }

	protected override void Setup()
    {';  
        SELECT  @Keys+=''+
		case when @count=1 then 
		'Id(k => k.' + COLUMN_NAME + ')'  
		else
		'
		.KeyProperty(k => k.' + COLUMN_NAME + ',"'+COLUMN_NAME+'")'  
		end
        FROM  
        (  
            SELECT TOP 100 *  
            FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE  
            WHERE OBJECTPROPERTY(OBJECT_ID(CONSTRAINT_SCHEMA + '.' + QUOTENAME(CONSTRAINT_NAME)), 'IsPrimaryKey') = 1  
                  AND TABLE_NAME = @tabela  
            ORDER BY ORDINAL_POSITION  
        ) t; 
		SELECT @Result += case when @count>1 then 'CompositeId()' else '' end+@Keys + case when @Count=0 then '//tabela sem PK, não será incluida no DOMINIO' else '' end+';';
        --//Id(m => m.{});'  
        SELECT @Result += case when EKey ='' then
    '
	Cl(m => m.' + ColumnName + ').Column("'+ ColumnName +'")'+NameSql+MaxL+Number+';' 
	else 
	'
	//Cl(m => m.' + ColumnName + ').Column("'+ ColumnName +'")'+NameSql+MaxL+Number+';' 
	end
        FROM  
        (  
            SELECT replace(col.name, ' ', '_') ColumnName,   
                   column_id ColumnId,
				   '.CustomSqlType("'+ typ.name +'")' NameSql,isnull(k.COLUMN_NAME,'') EKey,
				   --CASE WHEN typ.collation_name IS NOT NULL THEN '.Length('+cast(col.max_length AS varchar(100))+')' ELSE '' end MaxL,
				   CASE WHEN typ.collation_name IS NOT NULL THEN '.Tamanho('+case when col.max_length=-1 then 'int.MaxValue' else cast(col.max_length AS varchar(100)) end+')' ELSE '' end MaxL,
				   --CASE WHEN typ.name in('numeric','decimal','money') THEN '.Precision('+cast(col.precision AS varchar(100))+').Scale('+cast(col.scale AS varchar(100))+')' ELSE '' end Number
				   CASE WHEN typ.name in('numeric','decimal','money') THEN '.Decimal('+cast(col.precision AS varchar(100))+','+cast(col.scale AS varchar(100))+')' ELSE '' end Number
            FROM sys.columns col  
                 JOIN sys.types typ ON col.system_type_id = typ.system_type_id  
                                       AND col.user_type_id = typ.user_type_id  
				LEFT JOIN (SELECT *
            FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE  
            WHERE OBJECTPROPERTY(OBJECT_ID(CONSTRAINT_SCHEMA + '.' + QUOTENAME(CONSTRAINT_NAME)), 'IsPrimaryKey') = 1  
                  AND TABLE_NAME = @TableName)k on k.COLUMN_NAME=col.name
            WHERE object_id = OBJECT_ID(@TableName)   AND col.name<>'OptimisticLockField' 
        ) t  
        ORDER BY ColumnId; 
        SET @Result = @Result + '  
	}  
}';  
        select @Result;  
    END;
# Projeto - C # gerador de estrutura lógica

### Versão inicial do projeto.

- [ClassToNhibernate](https://github.com/isaiasnas/ClassToNhibernate)

Gerador de class para utilização **NHIBERNATE**,  ...
[documentação](https://github.com/isaiasnas/ClassToNhibernate/blob/master/README.md)

## Configuração
```csharp
    internal class InitConfig
    {
       static internal IDictionary<string,string> _tables = new Dictionary<string, string> {
           { "Tabela","Alias" },
       };
       static string _stringConnection = $";";

        public static IEnumerable<string> GetTables()
        {
            try
            {
                IList<string> tables = new List<string>();
                using (var connection = new SqlConnection(_stringConnection))
                {
                    foreach (var table in _tables)
                    {
                        var query = connection.ExecuteScalar<string>("create_class",
                            new
                            {
                                @tabela = table.Key,
                                @serializacao = 1,
                                @comentario = 0,
                                @override = 1,
                                @overrideFull = 0,
                                @generic = 1,
                                @baseClassName = "DbDtoBase",
                                @tabelaAlias = table.Value
                            }, commandType: CommandType.StoredProcedure);
                        tables.Add(query);
                    }
                }
                return tables;
            }
            catch
            {
                return default(IEnumerable<string>);
            }
        }

        public static IEnumerable<string> GetConfigs()
        {
            try
            {
                IList<string> tables = new List<string>();
                using (var connection = new SqlConnection(_stringConnection))
                {
                    foreach (var table in _tables)
                    {
                        var query = connection.ExecuteScalar<string>("create_class_config_nhibernate",
                            new
                            {
                                @tabela = table.Key,
                                @tabelaAlias = table.Value
                            }, commandType: CommandType.StoredProcedure);
                        tables.Add(query);
                    }
                }
                return tables;
            }
            catch
            {
                return default(IEnumerable<string>);
            }
        }

        public static string KEY = @"CONNECTION-DEFAULT";

        public static void Config()
        {
            try
            {
                /**/
                var uconfigBase = new UnitOfWorkConfig
                {
                    FormatSql = true,
                    ShowSql = true,
                    Nome = KEY,
                    Namespace = "namespace.root",
                    Assembly = Assembly.GetExecutingAssembly(),
                    Provider = Provider.SqlServer2008,
                    ConnectionString = _stringConnection,
                    LogScript = (log) => { System.Diagnostics.Trace.WriteLine(log); },
                };


                UnitOfWorkConfig.Configure(uconfigBase);

                UnitOfWorkConfig.SetEasyLog();

                using (
                    var unitLocal = UnitOfWork.Make(KEY))
                {

                }
            }
            catch (Exception ex)
            {
                throw ex;
            }
        }
    }
```

## Geração de classes
```csharp
  private static void Configuracao()
        {
            var tables = InitConfig.GetTables();
            var configs = InitConfig.GetConfigs();

            var classTable = string.Join(Environment.NewLine, tables);
            var classConfig = string.Join(Environment.NewLine, configs);

            InitConfig.Config();
            Unit = UnitOfWork.Make(InitConfig.KEY);
        }
```
## Histórico

Versão | Status | Data
----------|--------|-------------
0.0.2 | beta | 2021/04/10
0.0.1 | beta | 2020/05/18
0.0.0 | beta | 2019/09/20

## License

[MIT](https://github.com/isaiasnas/ClassToNhibernate/blob/master/LICENSE)

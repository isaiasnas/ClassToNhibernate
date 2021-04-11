# Projeto - C # gerador de estrutura lógica

### Versão inicial do projeto.

- [ClassToNhibernate](https://github.com/isaiasnas/ClassToNhibernate)

Gerador de class para utilização **NHIBERNATE**,  ...
[documentação](https://github.com/isaiasnas/ClassToNhibernate/blob/master/README.md)

## Configuração
```csharp
public class Config
{
    const string TEMPLATE_CLASS = @"using EasyInfo.DataAccess;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace {0}
{{
{1}
}}";

    const string TEMPLATE_CLASS_CONFIG = @"using EasyInfo.DataAccess;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
//referência de entidade
using {2};

namespace {0}
{{
{1}
}}";

    static string _stringConnection = $"server={0};initial catalog={1};user id={2};password={3};";

    public static IEnumerable<string> GetTables(string @namespace = "", string dir = "")
    {
        try
        {
            IList<string> @collection = new List<string>();
            using (var connection = new SqlConnection(_stringConnection))
            {
                foreach (var table in MapTables.Tables)
                {
                    var @class = connection.ExecuteScalar<string>("create_class",
                        new
                        {
                            @tabela = table.Table,
                            @serializacao = 1,
                            @comentario = 1,
                            @override = 1,
                            @overrideFull = 0,
                            @generic = 1,
                            @baseClassName = "DbDtoBase",
                            @tabelaAlias = table.Classe
                        }, commandType: CommandType.StoredProcedure);
                    @collection.Add(@class);


                    TablesToClass(table.Classe, @class?.Trim(), @namespace, dir);

                }
            }
            return @collection;
        }
        catch
        {
            return default(IEnumerable<string>);
        }
    }

    public static bool MakeEntities(string @namespace = "", string dir = "")
    {
        try
        {
            GetTables(@namespace, dir);
            return true;
        }
        catch (Exception ex)
        {
            return default(bool);
        }
    }

    public static bool MakeRepositories(string @namespace,string @namespaceEntity, string dir)
    {
        try
        {
            GetConfigs(@namespace, @namespaceEntity, dir);
            return true;
        }
        catch (Exception ex)
        {
            return default(bool);
        }
    }


    static void TablesToClass(string @className, string @class, string @namespace, string dir, bool config = false,string @namespaceEntity="")
    {
        try
        {
            if (string.IsNullOrWhiteSpace(@namespace) || string.IsNullOrWhiteSpace(dir)) return;

            var file = System.IO.Path.Combine(dir, $"{@className}{(config?"ConfigRepo":"")}.cs");
            var template = !config?
                string.Format(TEMPLATE_CLASS, @namespace, @class):
                string.Format(TEMPLATE_CLASS_CONFIG, @namespace, @class, @namespaceEntity);
            System.IO.File.WriteAllText(file, template);
        }
        catch (Exception ex)
        {
        }
    }

    public static IEnumerable<string> GetConfigs(string @namespace ,string @namespaceEntity, string dir)
    {
        try
        {
            IList<string> @collection = new List<string>();
            using (var connection = new SqlConnection(_stringConnection))
            {
                foreach (var table in MapTables.Tables)
                {
                    var @class = connection.ExecuteScalar<string>("create_class_config_nhibernate",
                        new
                        {
                            @tabela = table.Table,
                            @tabelaAlias = table.Classe,
                            @dominio = table.Dominio
                        }, commandType: CommandType.StoredProcedure);
                    @collection.Add(@class);

                    TablesToClass(table.Classe, @class?.Trim(), @namespace, dir, true, @namespaceEntity);
                }
            }
            return @collection;
        }
        catch
        {
            return default(IEnumerable<string>);
        }
    }

    public static string KEY = @"CONNECTION-DEFAULT";

    public static void Init()
    {
        try
        {
            /**/
            var uconfigBase = new UnitOfWorkConfig
            {
                FormatSql = true,
                ShowSql = true,
                Nome = KEY,
                Namespace = "assembly.root",
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
[TestFixture]
public class InitTeste
{
    protected UnitOfWork Unit;

    [TestCase, Order(1)]
    public void CriacaoDeEntidades()
    {
        var execute = Util.Config.MakeEntities("","");
        Assert.IsTrue(execute, "<ERROR>");
    }

    [TestCase,Order(2)]
    public void CriacaoDeRepositorio()
    {
        var execute = Util.Config.MakeRepositories("", "", @"");
        Assert.IsTrue(execute, "<ERROR>");
    }

    [TestCase, Order(3)]
    public void StartDb()
    {
        Util.Config.Init();
        Unit = UnitOfWork.Make(Util.Config.KEY);

        /**/
        var collection = Unit.Query<Entidade>().ToList();
        Assert.IsTrue(1==1, "<ERROR>");
    }
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

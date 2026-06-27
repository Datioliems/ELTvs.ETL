// Reconstructed helper for the SSIS Script Task.
// The original project stores only the VSTA project reference in Package.dtsx,
// not a standalone .cs source file. Review and test before replacing the task.

using System;
using System.Data;
using System.Data.OleDb;
using Microsoft.SqlServer.Dts.Runtime;

public void Main()
{
    object resultSet = Dts.Variables["User::LastRunObject"].Value;
    var table = resultSet as DataTable;

    // An OLE DB Execute SQL Task commonly returns an ADO recordset.
    if (table == null)
    {
        table = new DataTable();
        using (var adapter = new OleDbDataAdapter())
        {
            adapter.Fill(table, resultSet);
        }
    }

    foreach (DataRow row in table.Rows)
    {
        string tableName = Convert.ToString(row["table_name"]);
        DateTime lastRun = Convert.ToDateTime(row["last_run"]);

        switch (tableName)
        {
            case "Dim_Customer":
                Dts.Variables["User::LastRun_Customer"].Value = lastRun;
                break;
            case "Dim_Product":
                Dts.Variables["User::LastRun_Product"].Value = lastRun;
                break;
            case "Dim_Staff":
                Dts.Variables["User::LastRun_Staff"].Value = lastRun;
                break;
            case "Dim_Geography_Store":
                Dts.Variables["User::LastRun_Store"].Value = lastRun;
                break;
            case "Fact_Sale":
                Dts.Variables["User::LastRun_FactSale"].Value = lastRun;
                break;
        }
    }

    Dts.TaskResult = (int)ScriptResults.Success;
}

enum ScriptResults
{
    Success = DTSExecResult.Success,
    Failure = DTSExecResult.Failure
}

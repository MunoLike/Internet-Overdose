using System;
using System.Diagnostics;
using System.Linq;
using System.Security.Principal;

namespace bootstrap
{
    internal class Program
    {
        static int Main(string[] args)
        {
            var principal = new WindowsPrincipal(WindowsIdentity.GetCurrent());
            var isAdmin = principal.IsInRole(WindowsBuiltInRole.Administrator);
            //Console.WriteLine("isAdmin: " + isAdmin);


            ProcessStartInfo psi = new ProcessStartInfo();
            if(args.Length == 0 ) { return -1; }
            psi.FileName = args[0];
            psi.CreateNoWindow = true;
            psi.UseShellExecute = false;
            if (args.Length > 1)
            {
                var ws_args = new ArraySegment<string>(args, 1, args.Length-1);
                psi.Arguments = String.Join(" ", ws_args);
                //foreach (var arg in args) { Console.WriteLine(arg); }
            }

            Process.Start(psi);

            //Console.ReadLine();
            return 0;
        }
    }
}
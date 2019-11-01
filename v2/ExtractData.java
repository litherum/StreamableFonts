import java.io.FileOutputStream;
import java.io.IOException;
import java.io.OutputStreamWriter;
import java.io.PrintStream;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.HashMap;
import net.minidev.json.JSONArray;
import net.minidev.json.JSONObject;
import org.apache.hadoop.conf.Configuration;
import org.apache.hadoop.fs.FileStatus;
import org.apache.hadoop.fs.FileSystem;
import org.apache.hadoop.fs.Path;
import org.apache.hadoop.io.MapFile;
import org.apache.hadoop.io.Text;
import org.apache.hadoop.io.Writable;
import org.apache.hadoop.io.WritableComparable;
import org.apache.hadoop.mapreduce.lib.output.MapFileOutputFormat;
import org.apache.nutch.parse.ParseText;
import org.apache.nutch.segment.SegmentReader;
import org.apache.nutch.util.HadoopFSUtil;
import org.apache.nutch.util.NutchConfiguration;

public class ExtractData {
    public static void main(String[] args) throws Exception {
        Configuration configuration = new Configuration();
        Path dir = new Path("/Users/mmaxfield/Downloads/apache-nutch-1.16/crawl_qq/segments");
        FileSystem fs = dir.getFileSystem(configuration);
        FileStatus[] fstats = fs.listStatus(dir, HadoopFSUtil.getPassDirectoriesFilter(fs));
        Path[] files = HadoopFSUtil.getPaths(fstats);
        JSONArray outputArray = new JSONArray();
        for (int i = 0; i < files.length; ++i) {
            Path path = new Path(files[i], ParseText.DIR_NAME);
            MapFile.Reader[] readers;
            try {
                readers = MapFileOutputFormat.getReaders(path, configuration);
            } catch (Exception e) {
                continue;
            }
            for (int j = 0; j < readers.length; ++j) {
                Class<?> keyClass = readers[j].getKeyClass();
                Class<?> valueClass = readers[j].getValueClass();
                if (!keyClass.getName().equals("org.apache.hadoop.io.Text"))
                  throw new IOException("Incompatible key (" + keyClass.getName() + ")");
                if (!valueClass.getName().equals("org.apache.nutch.parse.ParseText"))
                  throw new IOException("Incompatible value (" + valueClass.getName() + ")");
                Text key = new Text();
                ParseText value = new ParseText();
                while (readers[j].next(key, value)) {
                    JSONObject outputObject = new JSONObject();
                    outputObject.put("URL", key.toString());
                    outputObject.put("Contents", value.getText());
                    outputArray.add(outputObject);
                }
            }
        }
        try (PrintStream out = new PrintStream(new FileOutputStream("output.json"))) {
            out.print(outputArray.toJSONString());
        }
    }
}
